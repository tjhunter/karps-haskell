{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

{-! The data structures for the server part -}
module Spark.Server.Structures where

import Spark.Core.StructuresInternal
import Spark.Core.Dataset(UntypedNode)
import Spark.Core.Internal.Utilities
import Spark.Core.Internal.TypesStructures(DataType)
import Spark.Core.Internal.TypesFunctions()
import Spark.Core.Internal.Client

import Data.Text(Text, pack)
import Data.Aeson
import Data.Aeson.Types(Parser)
import GHC.Generics

{-| A path that is unique across all the application. -}
-- TODO: move this to the main data structures.
data GlobalPath = GlobalPath {
  gpSessionId :: !LocalSessionId,
  gpComputationId :: !ComputationID,
  gpLocalPath :: !NodePath
}

{-| A node that has already been seen before, and for which we have a path -}
data SeenNode = SeenNode {
  snNodeId :: !NodeId,
  snPath :: !GlobalPath
}

data Graph_ = Graph_ {
  gNodes :: ![UntypedNode]
}

{-| The request to transform a (functional) graph to a pinned graph.

This request will perform a number of optimizations in the process.
-}
data GraphTransform = GraphTransform {
  gtSessionId :: !LocalSessionId,
  gtComputationId :: !ComputationID,
  gtNodes :: ![UntypedNode],
  gtTerminalNodes :: ![NodePath],
  gtNodeMap :: ![SeenNode]
}


data SerializedNodeExtra = SerializedNodeExtra {

}

data GraphTransformSuccess = GraphTransformSuccess {
  gtsNodes :: ![UntypedNode],
  gtsNodeMapUpdate :: ![SeenNode]
}

data GraphTransformFailure = GraphTransformFailure {
  gtfMessage :: !Text
}

data GraphTransformResult =
    GTRSuccess GraphTransformSuccess
  | GTRFailure GraphTransformFailure


instance FromJSON SeenNode where
  parseJSON = withObject "SeenNode" $ \o -> do
    s <- o .: "session"
    nid <- o .: "node"
    c <- o .: "computation"
    p <- o .: "path"
    return $ SeenNode nid (GlobalPath s c p)

instance FromJSON Graph_ where
  parseJSON = withObject "Graph" $ \o -> do
    -- nodes <- o .: "nodes"
    return (Graph_ undefined)

instance FromJSON GraphTransform where
  parseJSON = withObject "GraphTransform" $ \o -> do
    s <- o .: "session"
    c <- o .: "computation"
    g <- o .: "graph"
    requested_paths <- o .: "requested_paths"
    node_map <- o .: "available_nodes"
    return $ GraphTransform s c (gNodes g) requested_paths node_map
