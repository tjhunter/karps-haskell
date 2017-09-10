{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleInstances #-}
-- The communication protocol with the server

module Spark.Core.Internal.Client where

import Data.Text(Text, pack)
import Lens.Family2((^.), (&), (.~))

import Spark.Core.StructuresInternal
import Spark.Core.Dataset(UntypedNode)
import Spark.Core.Internal.Utilities
import Spark.Core.Internal.ProtoUtils
import Spark.Core.Internal.TypesStructures(DataType)
import Spark.Core.Internal.TypesFunctions()
import Spark.Core.Internal.RowStructures(Cell)
import Spark.Core.Internal.BrainStructures(LocalSessionId)
import Spark.Core.Internal.ProtoUtils
import qualified Proto.Karps.Proto.Computation as PC
import qualified Proto.Karps.Proto.Interface as PI
import qualified Proto.Karps.Proto.Computation as PC
import qualified Proto.Karps.Proto.Computation as PC
import qualified Proto.Karps.Proto.ApiInternal as PAI

{-| The ID of an RDD in Spark.
-}
data RDDId = RDDId {
 unRDDId :: !Int
} deriving (Eq, Show, Ord)

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
} deriving (Show)

data BatchComputationResult = BatchComputationResult {
  bcrTargetLocalPath :: !NodePath,
  bcrResults :: ![(NodePath, [NodePath], PossibleNodeStatus)]
} deriving (Show)

data RDDInfo = RDDInfo {
 rddiId :: !RDDId,
 rddiClassName :: !Text,
 rddiRepr :: !Text,
 rddiParents :: ![RDDId]
} deriving (Show)

data SparkComputationItemStats = SparkComputationItemStats {
  scisRddInfo :: ![RDDInfo]
} deriving (Show)

data PossibleNodeStatus =
    NodeQueued
  | NodeRunning
  | NodeFinishedSuccess !(Maybe NodeComputationSuccess) !(Maybe SparkComputationItemStats)
  | NodeFinishedFailure NodeComputationFailure deriving (Show)

data NodeComputationSuccess = NodeComputationSuccess {
  -- Because Row requires additional information to be deserialized.
  ncsData :: Cell,
  -- The data type is also available, but it is not going to be parsed for now.
  ncsDataType :: DataType
} deriving (Show)

data NodeComputationFailure = NodeComputationFailure {
  ncfMessage :: !Text
} deriving (Show)

instance ToProto PI.CreateComputationRequest Computation where
  toProto = undefined

instance FromProto PC.ComputationResult (NodePath, PossibleNodeStatus) where
  fromProto = undefined

instance FromProto PC.BatchComputationResult BatchComputationResult where
  fromProto = undefined
