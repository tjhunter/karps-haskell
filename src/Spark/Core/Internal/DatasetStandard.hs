{-# LANGUAGE OverloadedStrings #-}

{-| The standard library of functions that operate on datasets.
-}
module Spark.Core.Internal.DatasetStandard(
  autocache,
  cache,
  uncache,
  identity,
  broadcastPair,
  -- Internal
  opnameCache,
  opnameUnpersist,
  opnameAutocache,
) where

import qualified Data.Text as T

import Spark.Core.Internal.DatasetStructures
import Spark.Core.Internal.OpStructures
import Spark.Core.Internal.DatasetFunctions
import Spark.Core.Internal.TypesFunctions

{-| Caches the dataset.

This function instructs Spark to cache a dataset with the default persistence
level in Spark (MEMORY_AND_DISK).

Note that the dataset will have to be evaluated first for the caching to take
effect, so it is usual to call `count` or other aggregrators to force
the caching to occur.
-}
cache :: Dataset a -> Dataset a
cache  n = n2 `parents` [untyped n]
  where n2 = emptyNodeStandard (nodeLocality n) (nodeType n) opnameCache

-- (internal)
opnameCache :: T.Text
opnameCache = "org.spark.Cache"


{-| Uncaches the dataset.

This function instructs Spark to unmark the dataset as cached. The disk and the
memory used by Spark in the future.

Unlike Spark, Karps is stricter with the uncaching operation:
 - the argument of cache must be a cached dataset
 - once a dataset is uncached, its cached version cannot be used again (i.e. it
   must be recomputed).

Karps performs escape analysis and will refuse to run programs with caching
issues.
-}
uncache :: ComputeNode loc a -> ComputeNode loc a
uncache  n = n2 `parents` [untyped n]
  where n2 = emptyNodeStandard (nodeLocality n) (nodeType n) opnameUnpersist

-- (internal)
opnameUnpersist :: T.Text
opnameUnpersist = "org.spark.Unpersist"

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
autocache n = n2 `parents` [untyped n]
  where n2 = emptyNodeStandard (nodeLocality n) (nodeType n) opnameAutocache

{-| The identity function.

Returns a compute node with the same datatype and the same content as the
previous node. If the operation of the input has a side effect, this side
side effect is *not* reevaluated.

This operation is typically used when establishing an ordering between some
operations such as caching or side effects, along with `logicalDependencies`.
-}
identity :: ComputeNode loc a -> ComputeNode loc a
identity n = n2 `parents` [untyped n]
  where n2 = emptyNodeStandard (nodeLocality n) (nodeType n) name
        name = if unTypedLocality (nodeLocality n) == Local
                then "org.spark.LocalIdentity"
                else "org.spark.Identity"


opnameAutocache :: T.Text
opnameAutocache = "org.spark.Autocache"


{-| Low-level operator that takes an observable and propagates it along the
content of an existing dataset.

Users are advised to use the Column-based `broadcast` function instead.
-}
broadcastPair :: Dataset a -> LocalData b -> Dataset (a, b)
broadcastPair ds ld = n `parents` [untyped ds, untyped ld]
  where n = emptyNodeStandard (nodeLocality ds) sqlt name
        sqlt = tupleType (nodeType ds) (nodeType ld)
        name = "org.spark.BroadcastPair"
