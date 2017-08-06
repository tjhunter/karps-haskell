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
    IntType
  | DoubleType
  | StringType
  | BoolType
  deriving (Enum, Generic, Show)
instance Encode BasicType
instance Decode BasicType

data SQLType = SQLType {
  stBasicType :: Optional 1 (Message BasicType),
  stArrayType :: Optional 2 (Message SQLType),
  stStructType :: Optional 3 (Message StructType),
  stNullable :: Optional 4 (Value Bool)
} deriving (Generic, Show)
instance Encode SQLType
instance Decode SQLType

data StructField = StructField {
  sfFieldName :: Optional 1 (Value Text),
  sfFieldType :: Optional 2 (Message SQLType)
} deriving (Generic, Show)
instance Encode StructField
instance Decode StructField

data StructType = StructType {
  stFields :: Repeated 1 (Message StructField)
} deriving (Generic, Show)






instance Encode StructType
instance Decode StructType
