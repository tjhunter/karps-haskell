{-# LANGUAGE DeriveGeneric #-}

module Spark.Proto.Graph.Graph where

import Data.Text
import GHC.Generics (Generic)
import Data.Aeson

import Spark.Core.StructuresInternal
import Spark.Core.Internal.OpStructures
import Spark.Core.Internal.TypesStructures
import Spark.Proto.Graph.Node(Node)

data Graph = Graph {
  nodes :: ![Node]
} deriving (Show, Generic)
instance FromJSON Graph
instance ToJSON Graph
