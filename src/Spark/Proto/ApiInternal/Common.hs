{-# LANGUAGE DeriveGeneric #-}

module Spark.Proto.ApiInternal.Common where

import GHC.Generics (Generic)
import Data.Aeson

import Spark.Core.StructuresInternal
import Spark.Core.Internal.Client(LocalSessionId)

data NodeMapItem = NodeMapItem {
  node :: !NodeId,
  path :: !NodePath,
  computation :: !ComputationID,
  session :: !LocalSessionId
} deriving (Generic, Show)
instance FromJSON NodeMapItem
instance ToJSON NodeMapItem
