{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

{-| The structures of data types in Karps.

For a detailed description of the supported types, see
http://spark.apache.org/docs/latest/sql-programming-guide.html#data-types

At a high-level, Spark DataFrames and Datasets are equivalent to lists of
objects whose type can be mapped to the same StructType:
Dataset a ~ ArrayType StructType (...)
Columns of a dataset are equivalent to lists of object whose type can be
mapped to the same DataType (either Strict or Nullable)
Local data (or "blobs") are single elements whose type can be mapped to a
DataType (either strict or nullable)
-}
module Spark.Core.Internal.TypesStructures where

import Data.Aeson
import Data.Vector(Vector)
import qualified Data.Vector as V
import qualified Data.Aeson as A
import qualified Data.Text as T
import GHC.Generics(Generic)
import Test.QuickCheck
import Control.Applicative

import Spark.Core.StructuresInternal(FieldName(..))
import Spark.Core.Internal.Utilities

-- The core type algebra

-- | The data types that are guaranteed to not be null: evaluating them will return a value.
data StrictDataType =
    IntType
  | DoubleType
  | StringType
  | BoolType
  | Struct !StructType
  | ArrayType !DataType
  deriving (Eq)

-- | All the data types supported by the Spark engine.
-- The data types can either be nullable (they may contain null values) or strict (all the values are present).
-- There are a couple of differences with the algebraic data types in Haskell:
-- Maybe (Maybe a) ~ Maybe a which implies that arbitrary nesting of values will be flattened to a top-level Nullable
-- Similarly, [[]] ~ []
data DataType =
    StrictType !StrictDataType
  | NullableType !StrictDataType deriving (Eq)

-- | A field in a structure
data StructField = StructField {
  structFieldName :: !FieldName,
  structFieldType :: !DataType
} deriving (Eq)

-- | The main structure of a dataframe or a dataset
data StructType = StructType {
  structFields :: !(Vector StructField)
} deriving (Eq)


-- Convenience types

-- | Represents the choice between a strict and a nullable field
data Nullable = CanNull | NoNull deriving (Show, Eq)

-- | Encodes the type of all the nullable data types
data NullableDataType = NullableDataType !StrictDataType deriving (Eq)

-- | A tagged datatype that encodes the sql types
-- This is the main type information that should be used by users.
data SQLType a = SQLType {
  -- | The underlying data type.
  unSQLType :: !DataType
} deriving (Eq, Generic)


instance Show DataType where
  show (StrictType x) = show x
  show (NullableType x) = show x ++ "?"

instance Show StrictDataType where
  show StringType = "string"
  show DoubleType = "double"
  show IntType = "int"
  show BoolType = "bool"
  show (Struct struct) = show struct
  show (ArrayType at) = "[" ++ show at ++ "]"

instance Show StructField where
  show field = (T.unpack . unFieldName . structFieldName) field ++ ":" ++ s where
    s = show $ structFieldType field

instance Show StructType where
  show struct = "{" ++ unwords (map show (V.toList . structFields $ struct)) ++ "}"

instance Show (SQLType a) where
  show (SQLType dt) = show dt


-- QUICKCHECK INSTANCES
-- TODO: move these outside to testing

instance Arbitrary StructField where
  arbitrary = do
    name <- elements ["_1", "a", "b", "abc"]
    dt <- arbitrary :: Gen DataType
    return $ StructField (FieldName $ T.pack name) dt

instance Arbitrary StructType where
  arbitrary = do
    fields <- listOf arbitrary
    return . StructType . V.fromList $ fields

instance Arbitrary StrictDataType where
  arbitrary = do
    idx <- elements [1,2] :: Gen Int
    return $ case idx of
      1 -> StringType
      2 -> IntType
      _ -> failure "Arbitrary StrictDataType"

instance Arbitrary DataType where
  arbitrary = do
    x <- arbitrary
    u <- arbitrary
    return $ if x then
      StrictType u
    else
      NullableType u

-- AESON INSTANCES


_toJSDT :: StrictDataType -> Nullable -> Value
_toJSDT sdt nl =
  let nullable = (if nl == CanNull then A.Bool True else A.Bool False) :: A.Value
      _primitive :: T.Text -> A.Value
      _primitive s = object ["basicType" .= A.String s, "nullable" .= nullable ]
  in case sdt of
    IntType -> _primitive "INT"
    DoubleType -> _primitive "DOUBLE"
    StringType -> _primitive "STRING"
    BoolType -> _primitive "BOOL"
    (Struct struct) ->
      object ["structType" .= toJSON struct, "nullable" .= nullable]
    (ArrayType at) ->
      object ["arrayType" .= toJSON at, "nullable" .= nullable]

instance ToJSON StructType where
  toJSON (StructType fields) =
    let
      _fieldToJson (StructField (FieldName n) dt) =
        object ["fieldName" .= A.String n,"fieldType" .= toJSON dt]
      fs = _fieldToJson <$> V.toList fields
    in object ["fields" .= fs]

-- Spark drops the info at the highest level.
instance ToJSON DataType where
  toJSON (StrictType dt) = _toJSDT dt NoNull
  toJSON (NullableType dt) = _toJSDT dt CanNull

-- Parsing

instance FromJSON DataType where
  parseJSON = withObject "DataType" $ \o -> do
    -- The standard JSON encoding may not encode the default values
    nullable <- o .:? "nullable" .!= False
    let _parsePrimitive x = case x of
            A.String "INT" -> return IntType
            A.String "DOUBLE" -> return DoubleType
            A.String "STRING" -> return StringType
            A.String "BOOL" -> return BoolType
            _ -> fail ("DataType: cannot parse primitive " ++ show x)
    let p = (o .: "basicType") >>= _parsePrimitive
    let aj = o .: "arrayType"
    let st = o .: "structType"
    dt <- (Struct <$> st) <|> (ArrayType <$> aj) <|> p
    let c = if nullable then NullableType else StrictType
    return (c dt)

instance FromJSON StructField where
  parseJSON = withObject "StructField" $ \o -> do
    n <- o .: "fieldName"
    dt <- o .: "fieldType"
    return $ StructField (FieldName n) dt

instance FromJSON StructType where
  parseJSON = withObject "StructType" $ \o -> do
    fs <- o .: "fields"
    return (StructType fs)
