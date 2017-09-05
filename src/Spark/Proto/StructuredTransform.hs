{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE DeriveAnyClass#-}

{-| The basic data structures for defining nodes. -}
module Spark.Proto.StructuredTransform where

import GHC.Generics (Generic)
import Data.Aeson
import Data.Text(Text)

data Column = Column {
  struct :: !(Maybe ColumnStructure),
  function :: !(Maybe ColumnFunction),
  extraction :: !(Maybe ColumnExtraction),
  fieldName :: !(Maybe Text)
} deriving (Eq, Show, Generic, FromJSON, ToJSON)

data ColumnStructure = ColumnStructure {
  fields :: ![Column]
} deriving (Eq, Show, Generic, FromJSON, ToJSON)

data ColumnFunction = ColumnFunction {
  functionName :: !Text,
  inputs :: ![Column]
} deriving (Eq, Show, Generic, FromJSON, ToJSON)

data ColumnExtraction = ColumnExtraction {
  path :: ![Text]
} deriving (Eq, Show, Generic, FromJSON, ToJSON)

data Aggregation = Aggregation {
  op :: !(Maybe AggregationFunction),
  struct :: !(Maybe AggregationStructure),
  fieldName :: !(Maybe Text)
} deriving (Eq, Show, Generic, FromJSON, ToJSON)

data AggregationFunction = AggregationFunction {
  functionName :: !Text,
  inputs :: ![ColumnExtraction]
} deriving (Eq, Show, Generic, FromJSON, ToJSON)

data AggregationStructure = AggregationStructure {
  fields :: ![Aggregation]
} deriving (Eq, Show, Generic, FromJSON, ToJSON)
