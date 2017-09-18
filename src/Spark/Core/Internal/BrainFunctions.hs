{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE FlexibleInstances #-}
{-# OPTIONS_GHC -fno-warn-orphans #-} -- not sure if this is a good idea.

{-| This file is the major entry point for the Karps compiler.

This part of the computation is stateless and does not depend on the
DSL or on the server.
-}
module Spark.Core.Internal.BrainFunctions(
  TransformReturn,
  performTransform) where

import qualified Data.Map.Strict as M
import qualified Data.List.NonEmpty as N
import qualified Data.Text as T
import qualified Data.Vector as V
import Data.Map.Strict(Map)
import Data.Text(Text)
import Data.List(elemIndex)
import Data.Maybe(catMaybes)
import Data.Default
import Formatting
import GHC.Stack(prettyCallStack)
import Lens.Family2((&), (.~))
import Data.Functor.Identity(runIdentity, Identity)

import Spark.Core.Internal.BrainStructures
import Spark.Core.Internal.Utilities
import Spark.Core.Internal.ProtoUtils
import Spark.Core.Internal.ComputeDag(ComputeDag(..), computeGraphMapVerticesI, computeGraphMapVertices, graphVertexData, graphAdd, reverseGraph)
import Spark.Core.Internal.DatasetStd(localityToProto)
import Spark.Core.Internal.DAGStructures
import Spark.Core.Internal.DatasetFunctions(buildOpNode')
import Spark.Core.Internal.OpFunctions(simpleShowOp, extraNodeOpData)
import Spark.Core.Internal.OpStructures
import Spark.Core.Internal.DatasetStructures(StructureEdge(..), OperatorNode(..), onLocality, onType, onOp)
import Spark.Core.StructuresInternal(NodeId, ComputationID, NodePath)
import Spark.Core.Internal.Display(displayGraph)
import Spark.Core.InternalStd.Observable(localPackBuilder)
import Spark.Core.Internal.TypesFunctions(structTypeTuple')
import Spark.Core.StructuresInternal(nodePathAppendSuffix, emptyFieldPath, fieldPath', unsafeFieldName, emptyNodeId)
import Spark.Core.Try
import qualified Proto.Karps.Proto.Computation as PC
import qualified Proto.Karps.Proto.Graph as PG
import qualified Proto.Karps.Proto.ApiInternal as PAI


type TransformReturn = Either GraphTransformFailure GraphTransformSuccess

{-| The main function that calls mos of the functions in the background.

This function adopts the nanopass design, in which each step performs at most
a couple of graph traversals (typically one).

For a list of all the steps done, look at the list of the steps in api_internal.proto
-}
performTransform ::
  CompilerConf ->
  NodeMap ->
  ResourceList ->
  ComputeGraph ->
  TransformReturn
performTransform conf cache resources = _transform phases where
  _m f x = if f conf then Just x else Nothing
  phases = catMaybes [
    _m ccUseNodePruning (PAI.REMOVE_UNREACHABLE, transPruneGraph),
    pure (PAI.MERGE_AGGREGATIONS, mergeStructuredAggregators),
    -- pure (PAI.REMOVE_OBSERVABLE_BROADCASTS, removeObservableBroadcasts),
    pure (PAI.DATA_SOURCE_INSERTION, transInsertResource resources),
    pure (PAI.POINTER_SWAP_1, transSwapCache cache),
    pure (PAI.AUTOCACHE_FULLFILL, transFillAutoCache),
    pure (PAI.FINAL, pure)
    ]


_transform :: [(PAI.CompilingPhase, ComputeGraph -> Try ComputeGraph)] -> ComputeGraph -> TransformReturn
_transform l cg = f l [(PAI.INITIAL, cg)] cg where
  f :: [(PAI.CompilingPhase, ComputeGraph -> Try ComputeGraph)] -> [(PAI.CompilingPhase, ComputeGraph)] -> ComputeGraph -> TransformReturn
  f [] [] _ = error "should not have zero phase"
  f [] l' cg' = Right $ GraphTransformSuccess cg' M.empty (reverse l')
  f ((phase, fun):t) l' cg' =
    case fun cg' of
      Right cg2 ->
        -- Success at applying this phase, moving on to the next one.
        f t l2 cg2 where l2 = (phase, cg2) : l'
      Left err ->
        -- This phase failed, we stop here.
        Left $ GraphTransformFailure err (reverse l')


transSwapCache :: NodeMap -> ComputeGraph -> Try ComputeGraph
transSwapCache cache cg = pure cg

transInsertResource :: ResourceList -> ComputeGraph -> Try ComputeGraph
transInsertResource resources cg = pure cg

transPruneGraph :: ComputeGraph -> Try ComputeGraph
transPruneGraph = pure

transFillAutoCache :: ComputeGraph -> Try ComputeGraph
transFillAutoCache = pure

mergeStructuredAggregators :: ComputeGraph -> Try ComputeGraph
mergeStructuredAggregators cg = do
    cg1 <- cg1t
    let cg2 = computeGraphMapVerticesI cg1 $ \mat _ -> opNode mat
    cg3 <- tryEither $ graphAdd cg2 (extraVxs cg1) (extraEdges1 cg1 ++ extraEdges2 cg1)
    return cg3
  where
    -- The reverse graph
    rcg = _traceGraph ("mergeStructuredAggregators rcg=\n") $ reverseGraph (_traceGraph ("mergeStructuredAggregators cg=\n") cg)
    -- From the descendants, the list of nodes that are aggregators.
    childAggs :: [(MergeAggTrans, StructureEdge)] -> [(OperatorNode, AggOp)]
    childAggs [] = []
    childAggs ((MATAgg on ao, ParentEdge):t) = (on, ao) : childAggs t
    childAggs (_:t) = childAggs t
    -- This graph indicates which nodes are merging material.
    rcg0 = computeGraphMapVerticesI rcg f where
      f on l = case (onOp on, traceHint ("childAggs: \non="<>show' on<>" \nl="<>show' l<>" \nres=") $ childAggs l) of
        (NodeReduction ao, _) -> MATAgg on ao
        (_, []) -> MATNormal on -- A regular node, no special aggregation
        (_, [_]) -> MATNormal on -- A node that get aggregated by a single op, nothing to do.
        (_, x : t) -> -- A node that gets aggregated more than once -> transform.
          MATMulti on aggOn childPaths where
            aggs = x : t
            aggs' = x :| t
            childPaths = onPath . fst <$> aggs
            childDts = onType . fst <$> aggs'
            -- Build the combined structured aggregate.
            aos = snd <$> aggs
            fnames = f' <$> zip [(1::Int)..] aos where
              f' (idx, _) = unsafeFieldName (sformat ("_"%sh) idx)
            ao = AggStruct . V.fromList $ uncurry AggField <$> zip fnames aos
            dt = structTypeTuple' childDts
            npath = nodePathAppendSuffix (onPath on) "_karps_merged_agg"
            cni = coreNodeInfo dt Local (NodeReduction ao)
            aggOn = OperatorNode emptyNodeId npath cni
    -- Reverse the graph again and this time replace the mergeable aggregators
    -- by the identity nodes.
    g1 = traceHint ("mergeStructuredAggregators: g1=") $ reverseGraph rcg0
    opNode :: MergeAggTrans -> OperatorNode
    opNode (MATNormal on) = on
    opNode (MATAgg on _) = on
    opNode (MATMulti on _ _) = on
    -- This will be a compute graph. This is the base graph before adding
    -- the extra nodes and vertices.
    cg1t = computeGraphMapVertices g1 f' where
      f' (x @ MATNormal {}) _ = pure x
      f' (x @ MATMulti {}) _ = pure x
      f' (MATAgg on aggOn) l = case _parentNodes l of
        [MATMulti _ _ paths] -> do
            -- Find the index of this node into the paths.
            idx <- tryMaybe (elemIndex (onPath on) paths) "mergeStructuredAggregators: Could not find element"
            -- Account for the 1-based indexing for the fields.
            let co = _extractFromTuple (idx + 1)
            let cni' = coreNodeInfo (onType on) Local (NodeLocalStructuredTransform co)
            let on' = on { onNodeInfo = cni' }
            return $ MATAgg on' aggOn
        l' ->
          -- This is a programming error
          tryError $ sformat ("Expected a single MATMulti node but got "%sh%". This happend whil processing node MatAGG"%sh) (l', l) (on, aggOn)
    -- The extra vertices.
    extraVxs cg' = concatMap f' (graphVertexData cg') where
      f' (MATMulti _ aggOn _) = [nodeAsVertex aggOn]
      f' _ = []
    -- The new edges between the dataset and the composite aggregator
    extraEdges1 cg' = concatMap f' (graphVertexData cg') where
      f' (MATMulti on aggOn _) = [_makeParentEdge (onPath on) (onPath aggOn)]
      f' _ = []
    extraEdges2 cg' = concatMap f' (graphVertexData cg') where
      f' (MATMulti _ aggOn ps) = _makeParentEdge (onPath aggOn) <$> ps
      f' _ = []


data MergeAggTrans =
    MATNormal OperatorNode -- A normal node
  | MATAgg OperatorNode AggOp -- A node that contains a structured aggregation.
  | MATMulti OperatorNode OperatorNode [NodePath] -- A node that fans out in multiple aggregations
  deriving (Show)

{-| For local transforms, removes the broadcasting references by either
directly pointing to the single input, or packing the inputs and then
refering to the packed inputs.
-}
removeObservableBroadcasts :: ComputeGraph -> Try ComputeGraph
removeObservableBroadcasts cg = do
    -- Look at nodes that contain observable broadcast and make a map of the
    -- input.
    cg2 <- tryEither $ graphAdd cgUpdated extraVertices extraEdges
    -- TODO prune the edges that we have not removed.
    -- FIXME somehow there is no need to remove these edges??? must be a bug.
    return cg2
  where
    -- Replaces broadcast indices by reference to a tuple field.
    replaceIndices :: Bool -> ColOp -> ColOp
    replaceIndices _ (ce @ ColExtraction {}) = ce
    replaceIndices b (ColFunction sqln v t) = ColFunction sqln v' t where
      v' = replaceIndices b <$> v
    replaceIndices _ (cl @ ColLit {}) = cl
    replaceIndices b (ColStruct v) = ColStruct (f <$> v) where
      f (TransformField n val) = TransformField n (replaceIndices b val)
    replaceIndices True (ColBroadcast _) =
      -- TODO: check idx == 0
      ColExtraction emptyFieldPath
    replaceIndices False (ColBroadcast idx) = _extractFromTuple (idx + 1)
    origNode :: LocalPackTrans -> OperatorNode
    origNode (ThroughNode on) = on
    origNode (AddPack on _ _) = on
    cg' :: ComputeDag LocalPackTrans StructureEdge
    cg' = computeGraphMapVerticesI cg f where
      f on l = case onOp on of
        NodeLocalStructuredTransform co -> res where
          singleIndex = length l == 1
          no' = NodeLocalStructuredTransform (replaceIndices singleIndex co)
          cni' = (onNodeInfo on) { cniOp = no' }
          on' = on { onNodeInfo = cni' }
          res = case l of
            -- Just one parent -> no need to insert a pack
            [_] -> ThroughNode on'
            -- Multiple inputs -> need to insert a pack
            _ -> AddPack on' packOn ps where
              ps = onPath . origNode . fst <$> l
              parentOps = f' <$> l where
                f' (lpt, e) = (origNode lpt, e)
              npath = nodePathAppendSuffix (onPath on) "_karps_localpack"
              packOn' = buildOpNode' localPackBuilder emptyExtra npath parentOps
              packOn = forceRight packOn'
        -- Normal node -> let it through
        _ -> ThroughNode on
    -- The graph with the updated structured transforms.
    cgUpdated :: ComputeGraph
    cgUpdated = computeGraphMapVerticesI cg' f where
      f lpt _ = origNode lpt
    extraVertices = concat $ f' <$> graphVertexData cg' where
      f' (ThroughNode _) = []
      f' (AddPack _ packOn _) = [nodeAsVertex packOn]
    -- The edges coming flowing from parents -> local pack
    extraEdges1 = concat $ f' <$> graphVertexData cg' where
      f' (ThroughNode _) = []
      f' (AddPack _ packOn parents) = f'' <$> parents where
        f'' np = _makeParentEdge np (onPath packOn)
    -- The edges flowing from pack -> local structure
    extraEdges2 = concatMap f' (graphVertexData cg') where
      f' (ThroughNode _) = []
      f' (AddPack on packOn _) = [_makeParentEdge (onPath packOn) (onPath on)]
    extraEdges = extraEdges1 ++ extraEdges2

-- WATCH OUT: the flow is fromEdge -> toEdge
-- It is NOT in dependency
-- TODO: maybe this should be changed?
_makeParentEdge :: NodePath -> NodePath -> Edge StructureEdge
-- IMPORTANT: the edges in the graph are expected to represent dependency ordering, not flow.
_makeParentEdge npFrom npTo = Edge (parseNodeId npTo) (parseNodeId npFrom) ParentEdge

_parentNodes :: [(v, StructureEdge)] -> [v]
_parentNodes [] = []
_parentNodes ((v, ParentEdge):t) = v : _parentNodes t
_parentNodes (_ : t) = _parentNodes t

data LocalPackTrans = ThroughNode OperatorNode | AddPack OperatorNode OperatorNode [NodePath] deriving (Eq, Show)

{-| Builds an extractor from a tuple, given the index of the field of the tuple.
Does NOT do off-by-1 corrections. -}
_extractFromTuple :: Int -> ColOp
_extractFromTuple idx = ColExtraction . fieldPath' . (:[]) . unsafeFieldName $ sformat ("_"%sh) idx

_traceGraph :: forall v e. (Show v, Show e) => T.Text -> ComputeDag v e -> ComputeDag v e
_traceGraph txt cg = traceHint (txt <> txt') cg where
  txt1 = V.foldl (<>) "" $ f <$> cdVertices cg where
    f v = "vertex: " <> show' v <> "\n"
  txt2 = foldl (<>) "" $ f <$> (M.toList (cdEdges cg)) where
    f :: (VertexId, (V.Vector (VertexEdge e v))) -> T.Text
    f (k, v) = "edge group: " <> show' k <> " -> " <> V.foldl (<>) "" (f' <$> v) <> "\n" where
        f' :: VertexEdge e v -> T.Text
        f' (VertexEdge (Vertex vid _) (Edge fromId toId x)) = "(" <> show' fromId <> "->"<>show' x<>"->"<>show' toId<>":"<>show' vid<>"), "
  txt' = txt1 <> txt2

-- {-| Exposed for debugging -}
-- updateSourceInfo :: ComputeGraph -> SparkState (Try ComputeGraph)
-- updateSourceInfo cg = do
--   let sources = inputSourcesRead cg
--   if null sources
--   then return (pure cg)
--   else do
--     logDebugN $ "updateSourceInfo: found sources " <> show' sources
--     -- Get the source stamps. Any error at this point is considered fatal.
--     stampsRet <- checkDataStamps sources
--     logDebugN $ "updateSourceInfo: retrieved stamps " <> show' stampsRet
--     let stampst = sequence $ _f <$> stampsRet
--     let cgt = insertSourceInfo cg =<< stampst
--     return cgt


-- _parseStamp :: StampReturn -> Maybe (HdfsPath, Try DataInputStamp)
-- _parseStamp sr = case (stampReturn sr, stampReturnError sr) of
--   (Just s, _) -> pure (HdfsPath (stampReturnPath sr), pure (DataInputStamp s))
--   (Nothing, Just err) -> pure (HdfsPath (stampReturnPath sr), tryError err)
--   _ -> Nothing -- No error being returned for now, we just discard it.

-- ********* INSTANCES ***********

instance ToProto PAI.AnalysisMessage NodeError where
  toProto ne = (def :: PAI.AnalysisMessage)
      & PAI.content .~ (eMessage ne)
      & PAI.stackTracePretty .~ (T.pack . prettyCallStack . eCallStack $ ne)

instance FromProto PAI.NodeMapItem (NodeId, GlobalPath) where
  fromProto nmi = do
    nid <- extractMaybe' nmi PAI.maybe'node "node"
    np <- extractMaybe' nmi PAI.maybe'path "path"
    cid <- extractMaybe' nmi PAI.maybe'computation "computation"
    sid <- extractMaybe' nmi PAI.maybe'session "session"
    return (nid, GlobalPath sid cid np)

instance ToProto PAI.NodeMapItem (NodeId, GlobalPath) where
  toProto (nid, gp) = (def :: PAI.NodeMapItem)
      & PAI.node .~ toProto nid
      & PAI.path .~ toProto (gpLocalPath gp)
      & PAI.computation .~ toProto (gpComputationId gp)
      & PAI.session .~ toProto (gpSessionId gp)

instance ToProto PAI.CompilerStep (PAI.CompilingPhase, ComputeGraph) where
  toProto (phase, cg) = (def :: PAI.CompilerStep)
      & PAI.phase .~ phase
      & PAI.graph .~ toProto cg
      & PAI.graphDef .~ displayGraph cg

instance ToProto PAI.GraphTransformResponse GraphTransformSuccess where
  toProto gts = (def :: PAI.GraphTransformResponse)
    & PAI.pinnedGraph .~ toProto (gtsNodes gts)
    & PAI.nodeMap .~ (toProto <$> l)
    & PAI.steps .~ (toProto <$> gtsCompilerSteps gts) where
      l' = M.toList . M.map N.toList . gtsNodeMapUpdate $ gts
      l = [(nid, gp) | (nid, gps) <- l', gp <- gps ]

instance ToProto PAI.GraphTransformResponse GraphTransformFailure where
  toProto gtf = (def :: PAI.GraphTransformResponse)
    & PAI.steps .~ (toProto <$> gtfCompilerSteps gtf)
    & PAI.messages .~ [toProto (gtfMessage gtf)]

instance ToProto PG.Graph ComputeGraph where
  toProto cg = (def :: PG.Graph) & PG.nodes .~ l where
    f :: OperatorNode -> [((OperatorNode, PG.Node), StructureEdge)] -> (OperatorNode, PG.Node)
    f on l' = (on, (def :: PG.Node)
                & PG.locality .~ localityToProto (onLocality on)
                & PG.path .~ toProto (onPath on)
                & PG.opName .~ simpleShowOp (onOp on)
                & PG.opExtra .~ toProto (extraNodeOpData (onOp on))
                & PG.parents .~ lparents
                & PG.logicalDependencies .~ ldeps
                & PG.inferedType .~ toProto (onType on)) where
                  f' edgeType = toProto . onPath . fst . fst <$> filter ((edgeType ==) . snd) l'
                  lparents = f' ParentEdge
                  ldeps = f' LogicalEdge
    nodes = computeGraphMapVerticesI cg f
    l = snd <$> graphVertexData nodes
