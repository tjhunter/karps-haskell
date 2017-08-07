{-# LANGUAGE DeriveGeneric #-}

module Spark.Proto.ApiInternal.PerformGraphTransform where

import GHC.Generics (Generic)
import Data.Aeson

import Spark.Core.StructuresInternal
import Spark.Core.Internal.Client(LocalSessionId)
import Spark.Proto.Graph.Graph(Graph)
import Spark.Proto.ApiInternal.Common(NodeMapItem)

data PerformGraphTransform = PerformGraphTransform {
  session :: !LocalSessionId,
  computation :: !ComputationID,
  functionalGraph :: !Graph,
  availableNodes :: !(Maybe [NodeMapItem]),
  requestedPaths :: ![NodePath]
} deriving (Show, Generic)
instance FromJSON PerformGraphTransform
instance ToJSON PerformGraphTransform
