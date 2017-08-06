{-# LANGUAGE DeriveGeneric #-}

module Spark.Proto.ApiInternal.Common where

import Data.Text
import GHC.Generics (Generic)
import Data.Aeson

import Spark.Core.StructuresInternal
import Spark.Core.Internal.OpStructures
import Spark.Core.Internal.TypesStructures
import Spark.Core.Internal.Client(LocalSessionId)

data NodeMapItem = NodeMapItem {
  node :: !NodeId,
  path :: !NodePath,
  computation :: !ComputationID,
  session :: !LocalSessionId
} deriving (Generic, Show)
instance FromJSON NodeMapItem
instance ToJSON NodeMapItem
