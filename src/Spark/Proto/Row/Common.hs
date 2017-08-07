{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Spark.Proto.Row.Common where

import Data.Text
import GHC.Generics (Generic)
import Data.Aeson

import Spark.Core.Internal.RowStructures
import Spark.Core.Internal.RowUtils(jsonToCell)
import Spark.Core.Internal.TypesStructures

data CellWithType = CellWithType {
  cell :: !Cell,
  cellType :: !DataType
} deriving (Show, Generic)

instance FromJSON CellWithType where
  parseJSON = withObject "CellWithType" $ \o -> do
    dt <- o .: "cellType"
    cellv <- o .: "cell"
    case jsonToCell dt cellv of
      Left msg -> fail (unpack msg)
      Right z -> return $ CellWithType z dt
instance ToJSON CellWithType
