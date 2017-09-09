{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}

{-! The data structures for the server part -}
module Spark.Server.Structures where

import Data.Text(Text)
import Data.Map.Strict(Map)

import Spark.Core.StructuresInternal
import Spark.Core.Dataset(UntypedNode)
import Spark.Core.Internal.TypesFunctions()
import Spark.Core.Internal.ContextStructures(ComputeGraph)
import Spark.Core.Internal.Client
import Spark.Core.Internal.ProtoUtils
import qualified Proto.Karps.Proto.Graph as PGraph
import qualified Proto.Karps.Proto.ApiInternal as PAI


{-| A path that is unique across all the application. -}
-- TODO: move this to the main data structures.
data GlobalPath = GlobalPath {
  gpSessionId :: !LocalSessionId,
  gpComputationId :: !ComputationID,
  gpLocalPath :: !NodePath
} deriving (Eq, Show)

{-| A node that has already been seen before, and for which we have a path -}
data SeenNode = SeenNode {
  snNodeId :: !NodeId,
  snPath :: !GlobalPath
} deriving (Eq, Show)

-- TODO: use NonEmpty instead
type NodeMap = Map NodeId [GlobalPath]

{-| The request to transform a (functional) graph to a pinned graph.

This request will perform a number of optimizations in the process.
-}
data GraphTransform = GraphTransform {
  gtSessionId :: !LocalSessionId,
  gtComputationId :: !ComputationID,
  gtGraph :: !ComputeGraph,
  gtNodeMap :: !NodeMap
} deriving (Show)

data GraphTransformSuccess = GraphTransformSuccess {
  gtsNodes :: ![UntypedNode],
  -- gtsTerminalNodes :: ![UntypedNode],
  gtsNodeMapUpdate :: !NodeMap
}

data GraphTransformFailure = GraphTransformFailure {
  gtfMessage :: !Text
}

data GraphTransformResult =
    GTRSuccess GraphTransformSuccess
  | GTRFailure GraphTransformFailure

instance FromProto PAI.NodeMapItem (NodeId, GlobalPath) where
  fromProto nmi = do
    nid <- extractMaybe' nmi PAI.maybe'node "node"
    np <- extractMaybe' nmi PAI.maybe'path "path"
    cid <- extractMaybe' nmi PAI.maybe'computation "computation"
    sid <- extractMaybe' nmi PAI.maybe'session "session"
    return (nid, GlobalPath sid cid np)
