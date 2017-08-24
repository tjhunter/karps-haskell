{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE DeriveAnyClass#-}

{-| The basic data structures for defining nodes. -}
module Spark.Proto.Row where

import GHC.Generics (Generic)
import Data.Aeson
import Data.Text

import Spark.Core.Internal.TypesStructures
import Spark.Core.Internal.RowStructures
import Spark.Core.Internal.RowUtils(jsonToCell)


data CellWithType = CellWithType {
  cell :: !Cell,
  cellType :: !DataType
} deriving (Show, Generic, Eq, ToJSON)

instance FromJSON CellWithType where
  parseJSON = withObject "CellWithType" $ \o -> do
    dt <- o .: "cellType"
    cellv <- o .: "cell"
    case jsonToCell dt cellv of
      Left msg -> fail (unpack msg)
      Right z -> return $ CellWithType z dt
