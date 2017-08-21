{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DuplicateRecordFields #-}

{-| The basic data structures for defining nodes. -}
module Spark.Proto.Std.Basic where

import GHC.Generics (Generic)
import Data.Aeson

import Spark.Core.Internal.TypesStructures
import Spark.Core.Internal.OpStructures

data Placeholder = Placeholder {
  locality :: !Locality,
  dataType :: !DataType
} deriving (Eq, Show, Generic)
instance FromJSON Placeholder
instance ToJSON Placeholder
