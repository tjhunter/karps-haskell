{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}

{-| The data structures for the server part -}
module Spark.Server.StructureParsing where

import Spark.Core.StructuresInternal
import Spark.Core.Dataset(UntypedNode)
import Spark.Core.Internal.TypesFunctions()
import Spark.Core.Try

import Data.Text(Text)
import Debug.Trace
import Control.Arrow((&&&))
import qualified Data.Map.Strict as Map
import qualified Data.Vector as V
import Control.Monad(when)
import Data.Map.Strict(Map)
import Data.Maybe(fromMaybe)
import Data.ProtoLens.Message(Message)
import Lens.Family2 ((&), (.~), (^.), FoldLike)
import Formatting

import Spark.Server.Structures
import Spark.Core.Internal.Utilities(myGroupBy, pretty, sh)
import Spark.Core.Internal.DatasetFunctions
import Spark.Core.Internal.DatasetStructures(ComputeNode(..), unTypedLocality, StructureEdge(..), OperatorNode(..))
import Spark.Core.Internal.OpStructures
import Spark.Core.Internal.OpFunctions
import Spark.Core.Internal.ComputeDag
import Spark.Core.Internal.DAGStructures
import Spark.Core.Internal.ProtoUtils
import Spark.Core.Internal.NodeBuilder
import Spark.Core.Internal.ContextInternal(parseNodeId)
import Spark.Core.Internal.AggregationFunctions(collectBuilder)
import Spark.Core.Internal.DatasetStd(literalBuilderD)
import Spark.Core.Types
import qualified Proto.Karps.Proto.Graph as PG
import qualified Proto.Karps.Proto.ApiInternal as PAI


_parseInput :: PAI.PerformGraphTransform -> Try GraphTransform
_parseInput pgt = do
   sid <- extractMaybe' pgt PAI.maybe'session "session"
   cid <- extractMaybe' pgt PAI.maybe'computation "computation"
   l <- sequence $ fromProto <$> (pgt ^. PAI.availableNodes)
   let g = undefined
   return GraphTransform {
      gtSessionId = sid,
      gtComputationId = cid,
      gtGraph = g,
      gtNodeMap = myGroupBy l
    }

{-| Parses an outside transform into a GraphTransform.

TODO: add some notion of registry to handle unknown operations.
-}
parseInput :: PAI.PerformGraphTransform -> Try GraphTransform
parseInput pgt = undefined --do
  -- let requested = parseNodeId <$> requestedPaths pgt
  -- let nodes0 = PGraph.nodes . functionalGraph $ pgt
  -- -- As inputs, only keep the ids of the nodes that have no parents
  -- let inputs = _parseNodeId' <$> filter f nodes0 where
  --        f n = case (PGraph.parents n, PGraph.logicalDependencies n) of
  --          (Just (_ : _), _) -> False
  --          (_, Just (_ : _)) -> False
  --          _ -> True
  -- let vertices = f <$> nodes0 where
  --       f n = Vertex (_parseNodeId' n) n
  -- let edges = concatMap f nodes0 where
  --       f n = g ParentEdge (PGraph.parents n) ++ g LogicalEdge (PGraph.logicalDependencies n) where
  --            nid = _parseNodeId' n
  --            g' se np = Edge (parseNodeId np) nid se
  --            g _ Nothing = []
  --            g se (Just l) = g' se <$> l
  -- -- Make a first graph that checks the topology
  -- cg' <- tryEither $ buildCGraphFromList vertices edges inputs requested
  -- -- Make a second graph that calls the builders
  -- cg2 <- computeGraphMapVertices cg' _buildNode'
  -- let f1 (PAI.NodeMapItem nid p cid sid) = (nid, GlobalPath sid cid p)
  -- let nodeMap' = myGroupBy (f1 <$> fromMaybe [] (availableNodes pgt))
  -- return GraphTransform {
  --   gtSessionId = fromProto pgt,
  --   gtComputationId = fromProto pgt,
  --   gtGraph = cg2,
  --   gtNodeMap = nodeMap'
  -- }

-- (intenal) the parsed content of a node, which is then assembled into a
-- a graph.
data ParsedNode = ParsedNode {
  pnLocality :: !Locality,
  pnPath :: !NodePath,
  pnOpName :: !Text,
  pnExtra :: !OpExtra,
  pnParents :: ![NodePath],
  pnDeps :: ![NodePath],
  pnType :: !(Maybe DataType)
}

instance FromProto PG.Node ParsedNode where
  fromProto pn = do
    p <- extractMaybe' pn PG.maybe'path "path"
    extra <- extractMaybe' pn PG.maybe'opExtra "op_extra"
    parents' <- sequence $ fromProto <$> (pn ^. PG.parents)
    deps <- sequence $ fromProto <$> (pn ^. PG.logicalDependencies)
    dt <- case pn ^. PG.maybe'inferedType of
      Nothing -> pure Nothing
      _ ->
        pure <$> extractMaybe' pn PG.maybe'inferedType "infered_type"
    let loc = case pn ^. PG.locality of
          PG.DISTRIBUTED -> Distributed
          PG.LOCAL -> Local
    return ParsedNode {
      pnLocality = loc,
      pnPath = p,
      pnOpName = pn ^. PG.opName,
      pnExtra = extra,
      pnParents = parents',
      pnDeps = deps,
      pnType = dt
    }

{-| Writes the response. Nothing fancy here.
-}
protoResponse :: GraphTransformResult -> Try PAI.GraphTransformResponse
protoResponse (GTRSuccess (GraphTransformSuccess nodes _)) = undefined
  -- pure $ PAI.GraphTransformResponse (PGraph.Graph (_toNode <$> nodes)) []
protoResponse (GTRFailure (GraphTransformFailure msg)) =
  tryError msg


-- Internal stuff

data NodeWithDeps = NodeWithDeps {
  nwdNode :: !PG.Node,
  nwdParents :: ![UntypedNode],
  nwdLogicalDeps :: ![UntypedNode]
}

-- _parseNodeId' :: PGraph.Node -> VertexId
-- _parseNodeId' = parseNodeId . PGraph.path
--
-- _toNode :: UntypedNode -> PGraph.Node
-- _toNode un = PGraph.Node {
--       PGraph.locality = Just (unTypedLocality . nodeLocality $ un),
--       PGraph.path = nodePath un,
--       PGraph.opName = simpleShowOp (nodeOp un),
--       PGraph.opExtra = Just (OpExtra (Just (pretty extra))),
--       PGraph.parents = Just (nodePath <$> nodeParents un),
--       PGraph.logicalDependencies = Just (nodePath <$> nodeLogicalDependencies un),
--       PGraph.inferedType = unSQLType (nodeType un)
--     } where extra = extraNodeOpData (nodeOp un)
--
-- _parseNode :: NodeWithDeps -> Try UntypedNode
-- _parseNode nwd = do
--   let n = nwdNode nwd
--   let parentShapes = nodeShape <$> nwdParents nwd
--   --op <- _parseOp (PGraph.opName n) (fromMaybe (OpExtra Nothing) (PGraph.opExtra n))
--   cni <- _buildNode (PGraph.opName n) (fromMaybe (OpExtra Nothing) (PGraph.opExtra n)) parentShapes
--   let tpe = nsType (cniShape cni)
--   --tpe <- _parseType (PGraph.opName n) op (nwdParents nwd)
--   when (tpe /= PGraph.inferedType n) $
--     fail $ "_parseNode: incompatible types: infered=" ++ show tpe ++ " suggested=" ++ show (PGraph.inferedType n) ++ " path: " ++ show (PGraph.path n)
--   let un = ComputeNode {
--     _cnNodeId = error "_parseNode: should not access missing id here",
--     _cnOp = cniOp cni,
--     _cnType = tpe,
--     _cnParents = V.fromList (nwdParents nwd),
--     _cnLogicalDeps = V.fromList (nwdLogicalDeps nwd),
--     _cnLocality = fromMaybe Local (PGraph.locality n),
--     _cnName = Nothing,
--     _cnLogicalParents = Just (V.fromList (nwdParents nwd)),
--     _cnPath = PGraph.path n
--   }
--   let un2 = trace ("_parseNode: before id assignment: un=" ++ show un) un
--   let un' = updateNode un2 id
--   let un3 = trace ("_parseNode: after id assignment: un'=" ++ show un') un'
--   -- Make sure that the node ids are properly computed.
--   return un3
--
-- {-| The list of all the builders that are loaded in the program by default.
-- -}
-- _builders :: Map Text BuilderFunction
-- _builders = Map.fromList $ (nbName &&& nbBuilder) <$> [
--     collectBuilder,
--     literalBuilderD
--   ]
--
-- _buildNode' ::  PGraph.Node -> [(OperatorNode, StructureEdge)] -> Try OperatorNode
-- _buildNode' = error "_buildNode'"
--
-- {-| The main builder function. -}
-- _buildNode :: Text -> OpExtra -> [NodeShape] -> Try CoreNodeInfo
-- _buildNode opName extra parents' = case  Map.lookup opName _builders of
--   Just builder -> builder extra parents'
--   Nothing -> fail $ "_buildNode: unknown operation name: " ++ show opName
--
-- _nodesAsDict :: [UntypedNode] -> Map NodePath UntypedNode
-- _nodesAsDict l = Map.fromList (f <$> l) where
--   f n = (nodePath n, n)
