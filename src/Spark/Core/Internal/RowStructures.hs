{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE MultiParamTypeClasses #-}

module Spark.Core.Internal.RowStructures where

import Lens.Family2 ((^.))
import Formatting
import Data.Vector(Vector)
import qualified Data.Vector as V
import qualified Data.Text as T

import Spark.Core.Internal.ProtoUtils
import Spark.Core.Try
import qualified Proto.Karps.Proto.Row as P

-- | The basic representation of one row of data. This is a standard type that comes out of the
-- SQL engine in Spark.

-- | An element in a Row object.
-- All objects manipulated by the Spark framework are assumed to
-- be convertible to cells.
--
-- This is usually handled by generic transforms.
data Cell =
    Empty -- To represent maybe
    | IntElement !Int
    | DoubleElement !Double
    | StringElement !T.Text
    | BoolElement !Bool
    | RowArray !(Vector Cell)
    | RowElement !Row deriving (Show, Eq)

-- | A Row of data: the basic data structure to transport information
-- TODO rename to rowCells
data Row = Row {
    cells :: !(Vector Cell)
  } deriving (Show, Eq)


instance ToProto P.Cell Cell where
  toProto = cellToProto where
    cellToProto Empty = P.Cell Nothing
    cellToProto (IntElement i) = P.Cell . Just . P.Cell'IntValue $ fromIntegral i
    cellToProto (DoubleElement i) = P.Cell . Just . P.Cell'DoubleValue $ i
    cellToProto (StringElement i) = P.Cell . Just . P.Cell'StringValue $ i
    cellToProto (BoolElement i) = P.Cell . Just . P.Cell'BoolValue $ i
    cellToProto (RowArray v) = P.Cell . Just . P.Cell'ArrayValue . P.ArrayCell $ v' where
      v' = cellToProto <$> V.toList v
    cellToProto (RowElement (Row v)) = P.Cell . Just . P.Cell'StructValue . P.Row $ v' where
      v' = cellToProto <$> V.toList v

-- AESON INSTANCES

-- TODO(kps) add some workaround to account for the restriction of
-- JSON types:
-- int32 -> int32
-- double -> double
-- weird double -> string?
-- long/bigint -> string?

-- -- | Cell
-- instance ToJSON Cell where
--   toJSON Empty = object []
--   toJSON (DoubleElement d) = object ["doubleValue" .= toJSON d]
--   toJSON (IntElement i) = object ["intValue" .= toJSON i]
--   toJSON (BoolElement b) = object ["boolValue" .= toJSON b]
--   toJSON (StringElement s) = object ["stringValue" .= toJSON s]
--   toJSON (RowArray arr) = object ["arrayValue" .=
--     object ["values" .= toJSON arr]]
--   toJSON (RowElement row) = object ["structValue" .= toJSON row]
--
-- -- | Row
-- instance ToJSON Row where
--   toJSON (Row x) = object ["values" .= toJSON x]
