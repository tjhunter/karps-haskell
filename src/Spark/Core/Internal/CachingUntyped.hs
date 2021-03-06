{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}


{-| Implementation of the caching interfaces for the compute data structures.
-}
module Spark.Core.Internal.CachingUntyped(
  cachingType,
  uncache,
  autocacheGen
) where

import Control.Monad.Except

import Spark.Core.Internal.Caching
import Spark.Core.Internal.DatasetStructures
import Spark.Core.Internal.DatasetStd
import Spark.Core.Internal.DatasetFunctions
import Spark.Core.Internal.OpStructures
import Spark.Core.Internal.PathsUntyped()
import Spark.Core.Internal.DAGStructures
import Spark.Core.StructuresInternal


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

-- This still uses UntypedNode instead of OperatorNode
-- because it relies on the parents too.
cachingType :: UntypedNode -> CacheTry NodeCachingType
cachingType n = case nodeOp n of
  NodeLocalOp _ -> pure Stop
  -- NodeAggregatorReduction _ -> pure Stop
  NodeAggregatorLocalReduction _ -> pure Stop
  NodeOpaqueAggregator _ -> pure Stop
  NodeLocalLit _ _ -> pure Stop
  NodeStructuredTransform _ -> pure Through
  NodeLocalStructuredTransform _ -> pure Stop
  NodeDistributedLit _ _ -> pure Through
  NodeDistributedOp so | soName so == opnameCache ->
    pure $ CacheOp (vertexToId n)
  NodeDistributedOp so | soName so == opnameUnpersist ->
    case nodeParents n of
      [n'] -> pure $ UncacheOp (vertexToId n) (vertexToId n')
      _ -> throwError "Node is not valid uncache node"
  NodeDistributedOp so | soName so == opnameAutocache ->
    pure $ AutocacheOp (vertexToId n)
  NodeDistributedOp _ -> pure Through -- Nothing special for the other operations
  NodeBroadcastJoin -> pure Through
  NodeGroupedReduction _ -> pure Stop
  NodeReduction _ -> pure Stop
  NodePointer _ -> pure Stop -- It is supposed to be an observable

autocacheGen :: AutocacheGen UntypedNode
autocacheGen = AutocacheGen {
  deriveUncache = deriveUncache',
  deriveIdentity = deriveIdentity'
} where
    -- TODO: use path-based identification in the future
    -- f :: String -> VertexId -> VertexId
    -- f s (VertexId bs) = VertexId . C8.pack . (++s) . C8.unpack $ bs
    deriveIdentity' (Vertex _ un) =
      let x = identity un
          vid' = VertexId . unNodeId . nodeId $ x -- f "_identity" vid
      in Vertex vid' x
    deriveUncache' (Vertex _ un) =
      let x = uncache un
          vid' = VertexId . unNodeId . nodeId $ x -- f "_uncache" vid
      in Vertex vid' x
