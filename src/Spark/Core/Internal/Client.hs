{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE MultiParamTypeClasses #-}
-- The communication protocol with the server

module Spark.Core.Internal.Client where

import Data.Text(Text, pack)
import GHC.Generics

import Spark.Core.StructuresInternal
import Spark.Core.Dataset(UntypedNode)
import Spark.Core.Internal.Utilities
import Spark.Core.Internal.TypesStructures(DataType)
import Spark.Core.Internal.TypesFunctions()
import Spark.Core.Internal.RowStructures(Cell)
import Spark.Core.Internal.ProtoUtils
import qualified Proto.Karps.Proto.Computation as PC

{-| The ID of an RDD in Spark.
-}
data RDDId = RDDId {
 unRDDId :: !Int
} deriving (Eq, Show, Ord)

data LocalSessionId = LocalSessionId {
  unLocalSession :: !Text
} deriving (Eq, Show)

data Computation = Computation {
  cSessionId :: !LocalSessionId,
  cId :: !ComputationID,
  cNodes :: ![UntypedNode], -- TODO: check to replace with OperatorNode?
  -- Non-empty
  cTerminalNodes :: ![NodePath],
  -- The node at the top of the computation.
  -- Must be part of the terminal nodes.
  cCollectingNode :: !NodePath,
  -- This redundant information is not serialized.
  -- It is used internally to track the resulting nodes.
  cTerminalNodeIds :: ![NodeId]
} deriving (Show, Generic)

data BatchComputationKV = BatchComputationKV {
  bckvLocalPath :: !NodePath,
  bckvDeps :: ![NodePath],
  bckvResult :: !PossibleNodeStatus
} deriving (Show, Generic)

data BatchComputationResult = BatchComputationResult {
  bcrTargetLocalPath :: !NodePath,
  bcrResults :: ![(NodePath, [NodePath], PossibleNodeStatus)]
} deriving (Show, Generic)

data RDDInfo = RDDInfo {
 rddiId :: !RDDId,
 rddiClassName :: !Text,
 rddiRepr :: !Text,
 rddiParents :: ![RDDId]
} deriving (Show, Generic)

data SparkComputationItemStats = SparkComputationItemStats {
  scisRddInfo :: ![RDDInfo]
} deriving (Show, Generic)

data PossibleNodeStatus =
    NodeQueued
  | NodeRunning
  | NodeFinishedSuccess !(Maybe NodeComputationSuccess) !(Maybe SparkComputationItemStats)
  | NodeFinishedFailure NodeComputationFailure deriving (Show, Generic)

data NodeComputationSuccess = NodeComputationSuccess {
  -- Because Row requires additional information to be deserialized.
  ncsData :: Cell,
  -- The data type is also available, but it is not going to be parsed for now.
  ncsDataType :: DataType
} deriving (Show)

data NodeComputationFailure = NodeComputationFailure {
  ncfMessage :: !Text
} deriving (Show)


instance FromProto PC.SessionId LocalSessionId where
  fromProto (PC.SessionId x) = pure $ LocalSessionId x

instance ToProto PC.SessionId LocalSessionId where
  toProto = PC.SessionId . unLocalSession
