{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE FlexibleContexts #-}

{-| The standard library of functions operating on columns only.

You should use these functions if you care about expressing some
transforms involving columns only. Most of the functions here have
an overloaded equivalent in DatasetStandard which will work also for
datasets, dataframes, observables, etc.

This module is meant to be imported qualified.
-}
module Spark.Core.Internal.ColumnStandard(
  asDoubleCol
) where


import Spark.Core.Internal.ColumnStructures
import Spark.Core.Internal.ColumnFunctions
import Spark.Core.Internal.TypesGenerics(buildType)

asDoubleCol :: (Num a) => Column ref a -> Column ref Double
asDoubleCol = makeColOp1 "double" buildType
