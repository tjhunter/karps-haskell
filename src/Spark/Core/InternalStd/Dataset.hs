{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

{-| The standard library of functions that operate on datasets.

This file contains all the operations that are then refered to by more
-}
module Spark.Core.InternalStd.Dataset where

import qualified Data.Aeson as A
import qualified Data.Vector as V

import Spark.Core.Try
import Spark.Core.Row
import Spark.Core.Internal.TypesStructures
import Spark.Core.Internal.TypesFunctions
import Spark.Core.Internal.DatasetStructures
import Spark.Core.Internal.NodeBuilder
import Spark.Core.Internal.OpStructures
import Spark.Core.Internal.Utilities
import Spark.Core.Internal.RowUtils
import Spark.Core.Internal.DatasetFunctions
import Spark.Core.Internal.Caching
import Spark.Core.Internal.CachingUntyped
import Spark.Core.Internal.FunctionsInternals(broadcastPair)
import Spark.Proto.Std.Basic
import qualified Spark.Proto.Row.Common as PRow

{-| Automatically caches the dataset on a need basis, and performs deallocation
when the dataset is not required.

This function marks a dataset as eligible for the default caching level in
Spark. The current implementation performs caching only if it can be established
that the dataset is going to be involved in more than one shuffling or
aggregation operation.

If the dataset has no observable child, no uncaching operation is added: the
autocache operation is equivalent to unconditional caching.
-}
autocache :: Dataset a -> Dataset a
autocache n = forceRight $ fromBuilder1 n autocacheBuilder (nodeLocality n) (nodeType n)

autocacheBuilder :: NodeBuilder
autocacheBuilder = buildOpD opnameAutocache $ \dt ->
  pure $ cniStandardOp Distributed opnameAutocache dt A.Null


{-| Caches the dataset.

This function instructs Spark to cache a dataset with the default persistence
level in Spark (MEMORY_AND_DISK).

Note that the dataset will have to be evaluated first for the caching to take
effect, so it is usual to call `count` or other aggregrators to force
the caching to occur.
-}
cache :: Dataset a -> Dataset a
cache n = forceRight $ fromBuilder1 n cacheBuilder (nodeLocality n) (nodeType n)

cacheBuilder :: NodeBuilder
cacheBuilder = buildOpD opnameCache $ \dt ->
  pure $ cniStandardOp Distributed opnameCache dt A.Null
