{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE MultiParamTypeClasses #-}
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
import Data.Map.Strict(Map)
import Data.Text(Text)
import Data.Maybe(catMaybes)
import Data.Default
import Formatting
import GHC.Stack(prettyCallStack)
import Lens.Family2((&), (.~))
import Data.Functor.Identity(runIdentity, Identity)

import Spark.Core.Internal.BrainStructures
import Spark.Core.Internal.Utilities
import Spark.Core.Internal.ProtoUtils
import Spark.Core.Internal.ComputeDag(ComputeDag, computeGraphMapVerticesI, graphVertexData, graphAdd)
import Spark.Core.Internal.DatasetStd(localityToProto)
import Spark.Core.Internal.DAGStructures(Edge(..))
import Spark.Core.Internal.DatasetFunctions(buildOpNode')
import Spark.Core.Internal.OpFunctions(simpleShowOp, extraNodeOpData)
import Spark.Core.Internal.OpStructures
import Spark.Core.Internal.DatasetStructures(StructureEdge(..), OperatorNode(..), onLocality, onType, onOp)
import Spark.Core.StructuresInternal(NodeId, ComputationID, NodePath)
import Spark.Core.Internal.Display(displayGraph)
import Spark.Core.InternalStd.Observable(localPackBuilder)
import Spark.Core.StructuresInternal(nodePathAppendSuffix, emptyFieldPath, fieldPath', unsafeFieldName)
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
    pure (PAI.REMOVE_OBSERVABLE_BROADCASTS, removeObservableBroadcasts),
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
mergeStructuredAggregators = pure

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
    replaceIndices False (ColBroadcast idx) = ColExtraction (fieldPath' [fn]) where
      -- TODO: off by one?
      fn = unsafeFieldName $ sformat ("_"%sh) idx
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

data LocalPackTrans = ThroughNode OperatorNode | AddPack OperatorNode OperatorNode [NodePath] deriving (Eq, Show)

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
