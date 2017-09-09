{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE DeriveAnyClass#-}

{-| The basic data structures for defining nodes. -}
module Spark.Proto.Internal where

import GHC.Generics (Generic)
import Data.Aeson

import Spark.Core.Internal.TypesStructures
import Spark.Core.Internal.OpStructures
import Spark.Core.StructuresInternal
import Spark.Core.Internal.Client(LocalSessionId)
-- import Spark.Proto.Graph.Graph(Graph)

-- data Placeholder = Placeholder {
--   locality :: !Locality,
--   dataType :: !DataType
-- } deriving (Eq, Show, Generic, FromJSON, ToJSON)
--
-- data CreateComputationRequest = CreateComputationRequest {
--   session :: !LocalSessionId,
--   graph :: !Graph,
--   requestedComputation :: !ComputationID,
--   requestedPaths :: ![NodePath]
-- } deriving (Eq, Show, Generic, FromJSON, ToJSON)
