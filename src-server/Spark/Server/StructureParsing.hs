{-# LANGUAGE OverloadedStrings #-}

{-| The data structures for the server part -}
module Spark.Server.StructureParsing where

import Spark.Core.StructuresInternal
import Spark.Core.Dataset(UntypedNode)
import Spark.Core.Internal.TypesFunctions()
import Spark.Core.Try

import Data.Text(Text)
import Debug.Trace
import Control.Monad(when, unless)
import Data.Either(rights, lefts)
import Data.Map.Strict(Map)
import Data.Maybe(fromMaybe)
import qualified Data.Map.Strict as Map
import qualified Data.Vector as V
import Spark.Proto.ApiInternal.PerformGraphTransform(PerformGraphTransform)
import Spark.Proto.ApiInternal.GraphTransformResponse(GraphTransformResponse(..))
import Spark.Server.Structures
import Spark.Core.Internal.Utilities(myGroupBy, pretty)
import Spark.Core.Internal.DatasetFunctions
import Spark.Core.Internal.DatasetStructures(ComputeNode(..), unTypedLocality)
import Spark.Core.Internal.OpStructures
import Spark.Core.Internal.OpFunctions
import qualified Spark.Proto.Graph.Node as PNode
import qualified Spark.Proto.Graph.Graph as PGraph
import Spark.Proto.ApiInternal.Common(NodeMapItem(..))
import qualified Spark.Proto.ApiInternal.PerformGraphTransform as PGraphTransformRequest
import Spark.Proto.Graph.All(OpExtra(..))
import Spark.Core.Internal.AggregationFunctions(builderCollect)
import Spark.Core.Internal.DatasetFunctions(builderDistributedLiteral)
import Spark.Core.Types

{-| Parses an outside transform into a GraphTransform.

TODO: add some notion of registry to handle unknown operations.
-}
parseInput :: PerformGraphTransform -> Try GraphTransform
parseInput pgt = do
  let f1 (NodeMapItem nid p cid sid) = (nid, GlobalPath sid cid p)
  let nodeMap = myGroupBy (f1 <$> (fromMaybe [] (PGraphTransformRequest.availableNodes pgt)))
  nodes <- _parseGraph (PGraph.nodes . PGraphTransformRequest.functionalGraph $ pgt) Map.empty
  let dct = _nodesAsDict nodes
  let lookup' p = case Map.lookup p dct of
                    Just un -> Right un
                    Nothing -> Left p
  let requested = lookup' <$> (PGraphTransformRequest.requestedPaths pgt)
  let missingRequested = lefts requested
  unless (null missingRequested) $
    fail $ "Some node paths could not be found: " ++ show missingRequested
  let requestedNodes = rights requested
  return GraphTransform {
    gtSessionId = PGraphTransformRequest.session pgt,
    gtComputationId = PGraphTransformRequest.computation pgt,
    gtNodes = nodes,
    gtTerminalNodes = requestedNodes,
    gtNodeMap = nodeMap
  }

{-| Writes the response. Nothing fancy here.
-}
protoResponse :: GraphTransformResult -> Try GraphTransformResponse
protoResponse (GTRSuccess (GraphTransformSuccess nodes _ _)) =
  pure $ GraphTransformResponse (PGraph.Graph (_toNode <$> nodes)) []
protoResponse (GTRFailure (GraphTransformFailure msg)) =
  tryError msg


-- Internal stuff

data NodeWithDeps = NodeWithDeps {
  nwdNode :: !PNode.Node,
  nwdParents :: ![UntypedNode],
  nwdLogicalDeps :: ![UntypedNode]
}

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

_builders :: Map Text CoreNodeBuilder
_builders = Map.fromList [
    ("org.spark.Collect", builderCollect),
    ("org.spark.DistributedLiteral", builderDistributedLiteral)
  ]

{-| The main builder function. -}
_buildNode :: Text -> OpExtra -> [NodeShape] -> Try CoreNodeInfo
_buildNode opName extra parents = case  Map.lookup opName _builders of
  Just builder -> builder extra parents
  Nothing -> fail $ "_buildNode: unknown operation name: " ++ show opName

_nodesAsDict :: [UntypedNode] -> Map NodePath UntypedNode
_nodesAsDict l = Map.fromList (f <$> l) where
  f n = (nodePath n, n)

-- Parse a
_parseGraph :: [PNode.Node] -> Map NodePath UntypedNode -> Try [UntypedNode]
_parseGraph [] _ = pure []
_parseGraph l seen =
  let get n =
        let parents = sequence $ (`Map.lookup` seen) <$> (fromMaybe [] (PNode.parents n))
            deps = sequence $ (`Map.lookup` seen) <$> (fromMaybe [] (PNode.logicalDependencies n))
        in case NodeWithDeps n <$> parents <*> deps of
          Just nwd -> Right nwd
          Nothing -> Left n
      attempts = get <$> l
      readyNodes = rights attempts
      notReadyNodes = lefts attempts
  in case readyNodes of
    [] -> fail "Nodes contain a cycle"
    _ -> do
      -- We found some nodes that are ready and all independent
      -- Treat all of these, and move to the next ones
      filteredNodes <- sequence (_parseNode <$> readyNodes)
      let seen2 = Map.union seen (_nodesAsDict filteredNodes)
      rest <- _parseGraph notReadyNodes seen2
      return $ filteredNodes ++ rest
