{-# LANGUAGE DeriveGeneric #-}

module Spark.Proto.Graph.Node where

import Data.Text
import GHC.Generics (Generic)
import Data.Aeson

import Spark.Core.StructuresInternal
import Spark.Core.Internal.OpStructures
import Spark.Core.Internal.TypesStructures
import Spark.Proto.Graph.All(OpExtra)

data Node = Node {
  locality :: !Locality,
  path :: !NodePath,
  opName :: !Text,
  opExtra :: !OpExtra,
  parents :: ![NodePath],
  logicalDependencies :: ![NodePath],
  inferedType :: !DataType
} deriving (Show, Generic)
instance FromJSON Node
instance ToJSON Node

data Graph = Graph {
  nodes :: ![Node]
} deriving (Show, Generic)
instance FromJSON Graph
instance ToJSON Graph
