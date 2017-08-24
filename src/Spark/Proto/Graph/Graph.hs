{-# LANGUAGE DeriveGeneric #-}

module Spark.Proto.Graph.Graph where

import GHC.Generics (Generic)
import Data.Aeson

import Spark.Proto.Graph.Node(Node)

data Graph = Graph {
  nodes :: ![Node]
} deriving (Show, Generic, Eq)
instance FromJSON Graph
instance ToJSON Graph
