{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

module Spark.Core.ColumnSpec where

import Test.Hspec
import Data.List.NonEmpty(NonEmpty( (:|) ))

import Spark.Core.Context
import Spark.Core.Dataset
import Spark.Core.Column
import Spark.Core.Row
import Spark.Core.Functions
import qualified Spark.Core.ColumnFunctions as C
import Spark.Core.SimpleAddSpec(run, xrun)
import Spark.Core.Internal.LocalDataFunctions(iPackTupleObs)
import Spark.Core.Internal.DatasetFunctions(untypedLocalData)

myScaler :: Column ref Double -> Column ref Double
myScaler col =
  let cnt = asDouble (C.count col)
      m = C.sum col / cnt
      centered = col .- m
      stdDev = C.sum (centered * centered) / cnt
  in centered ./ stdDev


spec :: Spec
spec = do
  describe "local data operations" $ do
    xrun "broadcastPair_struct" $ do
      let ds = dataset [1] :: Dataset Int
      let cnt = C.count (asCol ds)
      let c = collect (asCol ds .+ cnt)
      res <- exec1Def c
      res `shouldBe` [2]
    run "LocalPack (doubles)" $ do
      let x = untypedLocalData (1 :: LocalData Double)
      let x2 = iPackTupleObs (x :| [x])
      res <- exec1Def x2
      res `shouldBe` rowCell [DoubleElement 1, DoubleElement 1]
    run "LocalPack" $ do
      let x = untypedLocalData (1 :: LocalData Int)
      let x2 = iPackTupleObs (x :| [x])
      res <- exec1Def x2
      res `shouldBe` rowCell [IntElement 1, IntElement 1]
    xrun "BroadcastPair" $ do
      let x = 1 :: LocalData Int
      let ds = dataset [2, 3] :: Dataset Int
      let ds2 = broadcastPair ds x
      res <- exec1Def (collect (asCol ds2))
      res `shouldBe` [(2, 1), (3, 1)]
      -- TODO: this combines a lot of elements together.
  describe "columns - integration" $ do
    xrun "mean" $ do
      let ds = dataset [-1, 1] :: Dataset Double
      let c = myScaler (asCol ds)
      res <- exec1Def (collect c)
      res `shouldBe` [-1, 1]
