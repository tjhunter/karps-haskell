{-# LANGUAGE OverloadedStrings #-}

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
import Control.Monad(when, unless)
import Data.Either(rights, lefts)
import Data.Map.Strict(Map)
import Data.Maybe(fromMaybe)
import Spark.Proto.ApiInternal.PerformGraphTransform(PerformGraphTransform)
import Spark.Proto.ApiInternal.GraphTransformResponse(GraphTransformResponse(..))
import Spark.Server.Structures
import Spark.Core.Internal.Utilities(myGroupBy, pretty)
import Spark.Core.Internal.DatasetFunctions
import Spark.Core.Internal.DatasetStructures(ComputeNode(..), unTypedLocality, StructureEdge(..), OperatorNode(..))
import Spark.Core.Internal.OpStructures
import Spark.Core.Internal.OpFunctions
import Spark.Core.Internal.ComputeDag
import Spark.Core.Internal.DAGStructures
import Spark.Core.Internal.NodeBuilder
import Spark.Core.Internal.ContextInternal(parseNodeId)
import qualified Spark.Proto.Graph.Node as PNode
import qualified Spark.Proto.Graph.Graph as PGraph
import Spark.Proto.ApiInternal.Common(NodeMapItem(..))
import qualified Spark.Proto.ApiInternal.PerformGraphTransform as PGraphTransformRequest
import Spark.Proto.Graph.All(OpExtra(..))
import Spark.Core.Internal.AggregationFunctions(collectBuilder)
import Spark.Core.Internal.DatasetStd(literalBuilderD)
import Spark.Core.Types

{-| Parses an outside transform into a GraphTransform.

TODO: add some notion of registry to handle unknown operations.
-}
parseInput :: PerformGraphTransform -> Try GraphTransform
parseInput pgt = do
  let requested = parseNodeId <$> PGraphTransformRequest.requestedPaths pgt
  let nodes0 = PGraph.nodes . PGraphTransformRequest.functionalGraph $ pgt
  -- As inputs, only keep the ids of the nodes that have no parents
  let inputs = _parseNodeId' <$> filter f nodes0 where
         f n = case (PNode.parents n, PNode.logicalDependencies n) of
           (Just (_ : _), _) -> False
           (_, Just (_ : _)) -> False
           _ -> True
  let vertices = f <$> nodes0 where
        f n = Vertex (_parseNodeId' n) n
  let edges = concatMap f nodes0 where
        f n = (g ParentEdge (PNode.parents n)) ++ (g LogicalEdge (PNode.logicalDependencies n)) where
             nid = _parseNodeId' n
             g' se np = Edge (parseNodeId np) nid se
             g _ Nothing = []
             g se (Just l) = g' se <$> l
  -- Make a first graph that checks the topology
  cg' <- tryEither $ buildCGraphFromList vertices edges inputs requested
  -- Make a second graph that calls the builders
  cg2 <- computeGraphMapVertices cg' _buildNode'
  let f1 (NodeMapItem nid p cid sid) = (nid, GlobalPath sid cid p)
  let nodeMap' = myGroupBy (f1 <$> (fromMaybe [] (PGraphTransformRequest.availableNodes pgt)))
  return GraphTransform {
    gtSessionId = PGraphTransformRequest.session pgt,
    gtComputationId = PGraphTransformRequest.computation pgt,
    gtGraph = cg2,
    gtNodeMap = nodeMap'
  }

{-| Writes the response. Nothing fancy here.
-}
protoResponse :: GraphTransformResult -> Try GraphTransformResponse
protoResponse (GTRSuccess (GraphTransformSuccess nodes _)) =
  pure $ GraphTransformResponse (PGraph.Graph (_toNode <$> nodes)) []
protoResponse (GTRFailure (GraphTransformFailure msg)) =
  tryError msg


-- Internal stuff

data NodeWithDeps = NodeWithDeps {
  nwdNode :: !PNode.Node,
  nwdParents :: ![UntypedNode],
  nwdLogicalDeps :: ![UntypedNode]
}

_parseNodeId' :: PNode.Node -> VertexId
_parseNodeId' = parseNodeId . PNode.path

_toNode :: UntypedNode -> PNode.Node
_toNode un = PNode.Node {
      PNode.locality = Just (unTypedLocality . nodeLocality $ un),
      PNode.path = nodePath un,
      PNode.opName = simpleShowOp (nodeOp un),
      PNode.opExtra = Just (OpExtra (Just (pretty extra))),
      PNode.parents = Just (nodePath <$> nodeParents un),
      PNode.logicalDependencies = Just (nodePath <$> nodeLogicalDependencies un),
      PNode.inferedType = unSQLType (nodeType un)
    } where extra = extraNodeOpData (nodeOp un)

_parseNode :: NodeWithDeps -> Try UntypedNode
_parseNode nwd = do
  let n = nwdNode nwd
  let parentShapes = nodeShape <$> nwdParents nwd
  --op <- _parseOp (PNode.opName n) (fromMaybe (OpExtra Nothing) (PNode.opExtra n))
  cni <- _buildNode (PNode.opName n) (fromMaybe (OpExtra Nothing) (PNode.opExtra n)) parentShapes
  let tpe = nsType (cniShape cni)
  --tpe <- _parseType (PNode.opName n) op (nwdParents nwd)
  when (tpe /= PNode.inferedType n) $
    fail $ "_parseNode: incompatible types: infered=" ++ show tpe ++ " suggested=" ++ show (PNode.inferedType n) ++ " path: " ++ show (PNode.path n)
  let un = ComputeNode {
    _cnNodeId = error "_parseNode: should not access missing id here",
    _cnOp = cniOp cni,
    _cnType = tpe,
    _cnParents = V.fromList (nwdParents nwd),
    _cnLogicalDeps = V.fromList (nwdLogicalDeps nwd),
    _cnLocality = fromMaybe Local (PNode.locality n),
    _cnName = Nothing,
    _cnLogicalParents = Just (V.fromList (nwdParents nwd)),
    _cnPath = PNode.path n
  }
  let un2 = trace ("_parseNode: before id assignment: un=" ++ show un) un
  let un' = updateNode un2 id
  let un3 = trace ("_parseNode: after id assignment: un'=" ++ show un') un'
  -- Make sure that the node ids are properly computed.
  return un3

{-| The list of all the builders that are loaded in the program by default.
-}
_builders :: Map Text BuilderFunction
_builders = Map.fromList $ (nbName &&& nbBuilder) <$> [
    collectBuilder,
    literalBuilderD
  ]

_buildNode' ::  PNode.Node -> [(OperatorNode, StructureEdge)] -> Try OperatorNode
_buildNode' = error "_buildNode'"

{-| The main builder function. -}
_buildNode :: Text -> OpExtra -> [NodeShape] -> Try CoreNodeInfo
_buildNode opName extra parents' = case  Map.lookup opName _builders of
  Just builder -> builder extra parents'
  Nothing -> fail $ "_buildNode: unknown operation name: " ++ show opName

_nodesAsDict :: [UntypedNode] -> Map NodePath UntypedNode
_nodesAsDict l = Map.fromList (f <$> l) where
  f n = (nodePath n, n)
