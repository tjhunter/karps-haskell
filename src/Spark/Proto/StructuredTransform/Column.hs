{-# LANGUAGE DeriveGeneric #-}

module Spark.Proto.StructuredTransform.Column where

import Data.Text
import GHC.Generics (Generic)
import Data.Aeson

import Spark.Core.StructuresInternal
import Spark.Core.Internal.OpStructures
import Spark.Core.Internal.TypesStructures

data Column = Column {
  struct :: Maybe ColumnStructure,
  function :: Maybe ColumnFunction,
  extraction :: Maybe ColumnExtraction,
  fieldName :: Maybe Text
} deriving (Show, Generic)
instance FromJSON Column
instance ToJSON Column

data ColumnStructure = ColumnStructure {
  fields :: ![Column]
} deriving (Show, Generic)
instance FromJSON ColumnStructure
instance ToJSON ColumnStructure

data ColumnFunction = ColumnFunction {
  functionName :: Text,
  inputs :: ![Column]
} deriving (Show, Generic)
instance FromJSON ColumnFunction
instance ToJSON ColumnFunction

data ColumnExtraction = ColumnExtraction {
  path :: ![Text]
} deriving (Show, Generic)
instance FromJSON ColumnExtraction
instance ToJSON ColumnExtraction
