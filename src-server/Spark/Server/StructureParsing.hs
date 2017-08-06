{-# LANGUAGE OverloadedStrings #-}

{-| The data structures for the server part -}
module Spark.Server.StructureParsing where

import Spark.Core.StructuresInternal
import Spark.Core.Dataset(UntypedNode)
import Spark.Core.Internal.TypesStructures(DataType)
import Spark.Core.Internal.TypesFunctions()
import Spark.Core.Internal.Client
import Spark.Core.Try

import Data.Text(Text, pack)
import Control.Monad(when)
import Data.Either(rights, lefts)
import Data.List.NonEmpty(NonEmpty)
import Data.Map.Strict(Map)
import qualified Data.Map.Strict as Map
import qualified Data.Vector as V
import Data.Aeson
import Data.List(partition)
import Data.Aeson.Types(Parser)
import GHC.Generics
import Spark.Proto.ApiInternal.PerformGraphTransform(PerformGraphTransform)
import Spark.Proto.ApiInternal.GraphTransformResponse(GraphTransformResponse)
import Spark.Server.Structures
import Spark.Core.Internal.Utilities(myGroupBy)
import Spark.Core.Internal.DatasetFunctions(nodePath, updateNode)
import Spark.Core.Internal.DatasetStructures(ComputeNode(..))
import Spark.Core.Internal.OpStructures(NodeOp)
import qualified Spark.Proto.Graph.Node as PNode
import qualified Spark.Proto.Graph.Graph as PGraph
import Spark.Proto.ApiInternal.Common(NodeMapItem(..))
import qualified Spark.Proto.ApiInternal.PerformGraphTransform as PGraphTransformRequest
import Spark.Proto.Graph.All(OpExtra)

{-| Parses an outside transform into a GraphTransform.

TODO: add some notion of registry to handle unknown operations.
-}
parseInput :: PerformGraphTransform -> Try GraphTransform
parseInput pgt = do
  let f1 (NodeMapItem nid p cid sid) = (nid, GlobalPath sid cid p)
  let nodeMap = myGroupBy (f1 <$> PGraphTransformRequest.availableNodes pgt)
  nodes <- _parseGraph (PGraph.nodes . PGraphTransformRequest.functionalGraph $ pgt) Map.empty
  let dct = _nodesAsDict nodes
  let lookup' n = case Map.lookup (nodePath n) dct of
                    Just un -> Right un
                    Nothing -> Left (nodePath n)
  let requested = lookup' <$> nodes
  let missingRequested = lefts requested
  when (not (null missingRequested)) $
    fail $ "Some node paths could not be found: " ++ show (missingRequested)
  let requestedNodes = rights requested
  return $ GraphTransform {
    gtSessionId = PGraphTransformRequest.session pgt,
    gtComputationId = PGraphTransformRequest.computation pgt,
    gtNodes = nodes,
    gtTerminalNodes = requestedNodes,
    gtNodeMap = undefined --nodeMap
  }

{-| Writes the response. Nothing fancy here.
-}
protoResponse :: GraphTransformResult -> GraphTransformResponse
protoResponse = undefined


-- Internal stuff

data NodeWithDeps = NodeWithDeps {
  nwdNode :: !PNode.Node,
  nwdParents :: ![UntypedNode],
  nwdLogicalDeps :: ![UntypedNode]
}

_parseNode :: NodeWithDeps -> Try UntypedNode
_parseNode nwd = do
  let n = nwdNode nwd
  op <- _parseOp (PNode.opName n) (PNode.opExtra n)
  tpe <- _parseType (PNode.opName n) op (nwdParents nwd)
  when (tpe /= PNode.inferedType n) $
    fail $ "_parseNode: incompatible types: infered=" ++ show tpe ++ " suggested=" ++ show (PNode.inferedType n) ++ " path: " ++ show (PNode.path n)
  let un = ComputeNode {
    _cnNodeId = error "_parseNode: should not access missing id here",
    _cnOp = op,
    _cnType = tpe,
    _cnParents = V.fromList (nwdParents nwd),
    _cnLogicalDeps = V.fromList (nwdLogicalDeps nwd),
    _cnLocality = PNode.locality n,
    _cnName = Nothing,
    _cnLogicalParents = Just (V.fromList (nwdParents nwd)),
    _cnPath = PNode.path n
  }
  -- Make sure that the node ids are properly computed.
  return $ updateNode un id


_parseOp :: Text -> OpExtra -> Try NodeOp
_parseOp = undefined

_parseType :: Text -> NodeOp -> [UntypedNode] -> Try DataType
_parseType = undefined

_nodesAsDict :: [UntypedNode] -> Map NodePath UntypedNode
_nodesAsDict l = Map.fromList (f <$> l) where
  f n = (nodePath n, n)

-- Parse a
_parseGraph :: [PNode.Node] -> Map NodePath UntypedNode -> Try [UntypedNode]
_parseGraph [] _ = pure []
_parseGraph l seen =
  let get n =
        let parents = sequence $ (`Map.lookup` seen) <$> (PNode.parents n)
            deps = sequence $ (`Map.lookup` seen) <$> (PNode.logicalDependencies n)
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
