{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE DeriveAnyClass#-}

{-| The basic data structures for defining nodes. -}
module Spark.Proto.Graph where

import GHC.Generics (Generic)
import Data.Aeson
import Data.Text
import Data.Aeson.Types(typeMismatch)

import Spark.Core.StructuresInternal
import Spark.Core.Internal.TypesStructures

-- | The dynamic value of locality.
-- There is still a tag on it, but it can be easily dropped.
data Locality =
    -- | The data associated to this node is local. It can be materialized
    -- and accessed by the user.
    Local
    -- | The data associated to this node is distributed or not accessible
    -- locally. It cannot be accessed by the user.
  | Distributed deriving (Show, Eq)

instance FromJSON Locality where
  parseJSON (String x) | x == "LOCAL" = return Local
  parseJSON (String x) | x == "DISTRIBUTED" = return Distributed
  parseJSON x = typeMismatch "Locality" x

instance ToJSON Locality where
  toJSON Local = toJSON ("LOCAL" :: Text)
  toJSON Distributed = toJSON ("DISTRIBUTED" :: Text)


data OpExtra = OpExtra {
  content :: !(Maybe Text)
} deriving (Show, Generic, Eq, FromJSON, ToJSON)

data Graph = Graph {
  nodes :: ![Node]
} deriving (Show, Generic, Eq, FromJSON, ToJSON)

data Node = Node {
  locality :: !(Maybe Locality), -- It is an enum and may be missing (protobuf reasons)
  path :: !NodePath,
  opName :: !Text,
  opExtra :: !(Maybe OpExtra),
  parents :: !(Maybe [NodePath]),
  logicalDependencies :: !(Maybe [NodePath]),
  inferedType :: !DataType
} deriving (Show, Generic, Eq, FromJSON, ToJSON)
