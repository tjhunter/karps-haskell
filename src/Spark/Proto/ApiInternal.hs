{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE DeriveAnyClass#-}

{-| The basic data structures for defining nodes. -}
module Spark.Proto.ApiInternal where

import GHC.Generics (Generic)
import Data.Aeson

import Spark.Core.StructuresInternal
import Spark.Core.Internal.Client(LocalSessionId)
import Spark.Proto.Graph(Graph)

data NodeMapItem = NodeMapItem {
  node :: !NodeId,
  path :: !NodePath,
  computation :: !ComputationID,
  session :: !LocalSessionId
} deriving (Eq, Show, Generic, FromJSON, ToJSON)

nmiSession :: NodeMapItem -> LocalSessionId
nmiSession = session

nmiComputation :: NodeMapItem -> ComputationID
nmiComputation = computation

data GraphTransformResponse = GraphTransformResponse {
  pinnedGraph :: !Graph,
  nodeMap :: ![NodeMapItem]
  -- No message for now.
} deriving (Eq, Show, Generic, FromJSON, ToJSON)

data PerformGraphTransform = PerformGraphTransform {
  session :: !LocalSessionId,
  computation :: !ComputationID,
  functionalGraph :: !Graph,
  availableNodes :: !(Maybe [NodeMapItem]),
  requestedPaths :: ![NodePath]
} deriving (Eq, Show, Generic, FromJSON, ToJSON)

pgtSession :: PerformGraphTransform -> LocalSessionId
pgtSession = session

pgtComputation :: PerformGraphTransform -> ComputationID
pgtComputation = computation
