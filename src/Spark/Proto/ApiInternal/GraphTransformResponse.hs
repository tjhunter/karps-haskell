{-# LANGUAGE DeriveGeneric #-}

module Spark.Proto.ApiInternal.GraphTransformResponse where

import GHC.Generics (Generic)
import Data.Aeson

import Spark.Proto.Graph.Graph(Graph)
import Spark.Proto.ApiInternal.Common(NodeMapItem)

data GraphTransformResponse = GraphTransformResponse {
  pinnedGraph :: !Graph,
  nodeMap :: ![NodeMapItem]
  -- No message for now.
} deriving (Show, Generic)
instance FromJSON GraphTransformResponse
instance ToJSON GraphTransformResponse
