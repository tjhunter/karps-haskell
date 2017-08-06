{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DataKinds     #-}

module Spark.Proto.Types where

import Data.Int
import Data.ProtocolBuffers
import Data.Text
import GHC.Generics (Generic)
import GHC.TypeLits
import Data.Monoid
import Data.Serialize

data BasicType =
    BasicTypeInt
  | BasicTypeDouble
  | BasicTypeString
  | BasicTypeBool
  deriving (Enum, Generic, Show)
instance Encode BasicType
instance Decode BasicType

data StructField = StructField {
  sfFieldName :: Optional 1 (Value Text),
  sfFieldType :: Optional 2 (Message SQLType)
} deriving (Generic, Show)
instance Encode StructField
instance Decode StructField

data StructType = StructType {
  stFields :: Optional 1 (Message StructField)
} deriving (Generic, Show)
instance Encode StructType
instance Decode StructType

data SQLType = SQLType {
  stBasicType :: Optional 1 (Message BasicType),
  stArrayType :: Optional 2 (Message SQLType),
  stStructType :: Optional 3 (Message StructType)
} deriving (Generic, Show)
instance Encode SQLType
instance Decode SQLType
