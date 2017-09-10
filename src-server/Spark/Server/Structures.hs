{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}

{-! The data structures for the server part -}
module Spark.Server.Structures where

import Data.Text(Text)
import Data.Map.Strict(Map)

import Spark.Core.StructuresInternal
import Spark.Core.Dataset(UntypedNode)
import Spark.Core.Internal.TypesFunctions()
import Spark.Core.Internal.ContextStructures(ComputeGraph)
import Spark.Core.Internal.Client
import Spark.Core.Internal.Utilities(NonEmpty)
import Spark.Core.Internal.ProtoUtils
import qualified Proto.Karps.Proto.Graph as PGraph
import qualified Proto.Karps.Proto.ApiInternal as PAI

-- {-| The request to transform a (functional) graph to a pinned graph.
--
-- This request will perform a number of optimizations in the process.
-- -}
-- data GraphTransform = GraphTransform {
--   gtSessionId :: !LocalSessionId,
--   gtComputationId :: !ComputationID,
--   gtGraph :: !ComputeGraph,
--   gtNodeMap :: !NodeMap
-- } deriving (Show)
--
-- data GraphTransformSuccess = GraphTransformSuccess {
--   gtsNodes :: ![UntypedNode],
--   -- gtsTerminalNodes :: ![UntypedNode],
--   gtsNodeMapUpdate :: !NodeMap
-- }
--
-- data GraphTransformFailure = GraphTransformFailure {
--   gtfMessage :: !Text
-- }
--
-- data GraphTransformResult =
--     GTRSuccess GraphTransformSuccess
--   | GTRFailure GraphTransformFailure
