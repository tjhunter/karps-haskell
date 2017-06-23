{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Spark.Core.Internal.ColumnStructures where

import Control.Arrow ((&&&))
import Data.Function(on)
import Data.Vector(Vector)

import Spark.Core.Internal.DatasetStructures
import Spark.Core.Internal.DatasetFunctions()
import Spark.Core.Internal.RowStructures
import Spark.Core.Internal.TypesStructures
import Spark.Core.Internal.OpStructures
import Spark.Core.StructuresInternal
import Spark.Core.Try


{-| A column of data from a dataset, which is all the distributed nodes
with a floating reference.

This column is typed: the operations on this column will be
validdated by Haskell's type inference.
-}
type Column ref a = ComputeNode LocDistributed ref a

{-| An untyped column of data from a dataset or a dataframe.

This column is untyped and may not be properly constructed. Any error
will be found during the analysis phase at runtime.
-}
type DynColumn = Try (ColumnData UnknownReference Cell)


-- | (dev)
-- The type of untyped column data.
type UntypedColumnData = ColumnData UnknownReference Cell

{-| (dev)
A column for which the type of the cells is unavailable (at the type level),
 but for which the origin is available at the type level.
-}
type GenericColumn ref = Column ref Cell

{-| A dummy data type that indicates the data referenc is missing.
-}
data UnknownReference

{-| A tag that carries the reference information of a column at a
type level. This is useful when creating column.

See ref and colRef.
-}
data ColumnReference a = ColumnReference
