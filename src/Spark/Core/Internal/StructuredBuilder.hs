{-# LANGUAGE OverloadedStrings #-}

{-| Contains a registry of all the known aggregation functions -}
module Spark.Core.Internal.StructuredBuilder(
  ColumnBuilderFunction,
  AggBuilderFunction,
  ColumnSQLBuilder(..),
  ColumnUDFBuilder(..),
  AggSQLBuilder(..),
  StructuredBuilderRegistry,
  colTypeStructured,
  aggTypeStructured,
  refineColBuilderPost,
  colBuilder1,
  colBuilder2,
  colBuilder2Homo,
  checkNumber,
  checkStrictDataType,
  checkStrictDataTypeList,
  -- Builder tools
  registrySqlCol,
  registryUdfCol,
  registrySqlAgg,
  buildStructuredRegistry
) where

import qualified Data.Map.Strict as M
import qualified Data.List.NonEmpty as N
import qualified Data.Vector as V
import Control.Arrow ((&&&))
import Formatting
import Data.List(find)

import Spark.Core.Internal.OpStructures
import Spark.Core.Internal.TypesStructures(DataType(..), StructField(..), StrictDataType(..), StructType(..), Nullable(..))
import Spark.Core.Internal.TypesFunctions(isNumber)
import Spark.Core.StructuresInternal(FieldName(..), unFieldPath, FieldPath)
import Spark.Core.Internal.Utilities
import Spark.Core.Try(Try, tryError)

{-| A column builder. No extra information required.

The output is supposed to be broadcastable.
-}
type ColumnBuilderFunction = [DataType] -> Try DataType

{-| Takes the type of the column and returns the type
of the element.

Compared to the column case, the aggregation builder also
returns information about universal aggregators.
-}
type AggBuilderFunction = DataType -> Try (DataType, Maybe SemiGroupOperator)

data ColumnSQLBuilder = ColumnSQLBuilder {
  csbName :: !SqlFunctionName,
  csbBuilder :: !ColumnBuilderFunction
}

data ColumnUDFBuilder = ColumnUDFBuilder {
  cubName :: !UdfClassName,
  cubBuilder :: !ColumnBuilderFunction
}

{-| The Universal aggregation builder.

The builder must respect a couple of laws to be valid:

1. it must be able to operate on a column of data, independently from the
the other columns. In other words, it needs not access to the complete
dataframe.

2. Its output must verify the monoid laws: the empty set projects to the
neutral element, and the union of dataset is a morphism.

Spark provides a few ways to implement universal aggregators:
 - as a SQL function (some of the built-ins)
 - using the UDAF interface (excluding the post-processing operation)
-}
data AggSQLBuilder = AggSQLBuilder {
  asbName :: !SqlFunctionName,
  asbBuilder :: !AggBuilderFunction
}

{-| A registry of builder functions for structured builders.
-}
data StructuredBuilderRegistry = StructuredBuilderRegistry {
  _registrySqlCol :: SqlFunctionName -> Maybe ColumnBuilderFunction,
  _registryUdfCol :: UdfClassName -> Maybe ColumnBuilderFunction,
  _registrySqlAgg :: SqlFunctionName -> Maybe AggBuilderFunction
}

registrySqlCol :: StructuredBuilderRegistry -> SqlFunctionName -> Maybe ColumnBuilderFunction
registrySqlCol = _registrySqlCol

registryUdfCol :: StructuredBuilderRegistry -> UdfClassName -> Maybe ColumnBuilderFunction
registryUdfCol = _registryUdfCol

registrySqlAgg :: StructuredBuilderRegistry -> SqlFunctionName -> Maybe AggBuilderFunction
registrySqlAgg = _registrySqlAgg

buildStructuredRegistry ::
  [ColumnSQLBuilder] ->
  [ColumnUDFBuilder] ->
  [AggSQLBuilder] ->
  StructuredBuilderRegistry
buildStructuredRegistry sqls udfs sqlAggs = StructuredBuilderRegistry f1 f2 f3 where
  f getName l = (`M.lookup` m) where
          m = M.map N.head . myGroupBy $ (getName &&& id) <$> l
  f1 = (csbBuilder <$>) . f csbName sqls
  f2 = (cubBuilder <$>) . f cubName udfs
  f3 = (asbBuilder <$>) . f asbName sqlAggs


{-| Given the data type of a column, infers the type of the output through
a structured transform. -}
colTypeStructured :: StructuredBuilderRegistry -> ColOp -> DataType -> Try DataType
colTypeStructured _ (ColExtraction fp) dt = _extraction' fp dt
colTypeStructured _ (ColLit dt' _) _ = pure dt'
colTypeStructured reg (ColFunction fname v) dt = do
  fun <- case registrySqlCol reg fname of
    Just b -> pure b
    Nothing -> tryError $ sformat ("colTypeStructured: cannot find sql column builder for name "%sh) fname
  args <- sequence $ (\co -> colTypeStructured reg co dt) <$> V.toList v
  fun args
colTypeStructured reg (ColStruct v) dt = StrictType . Struct . StructType <$> l where
  f (TransformField n val) = StructField n <$> colTypeStructured reg val dt
  l = sequence (f <$> v)

{-| Given the datatype of a column, infers the type of the output Observable through
a structured aggregation. -}
aggTypeStructured :: StructuredBuilderRegistry -> AggOp -> DataType -> Try DataType
aggTypeStructured _ AggUdaf {} _ =
  tryError $ sformat "aggTypeStructured: UDAF not implemented"
aggTypeStructured reg (AggFunction fname fp) dt = do
  dt' <- _extraction' fp dt
  fun <- case reg `registrySqlAgg` fname of
    Just fun' -> pure fun'
    Nothing -> tryError $ sformat ("Cannot find SQL aggregation function "%sh%" in registry") fname
  -- TODO: it currently drops the semi group information
  fst <$> fun dt'
aggTypeStructured reg (AggStruct v) dt = StrictType . Struct . StructType <$> l where
  f (AggField n val) = StructField n <$> aggTypeStructured reg val dt
  l = sequence (f <$> v)

checkNumber :: DataType -> Try ()
checkNumber dt =
  if isNumber dt
  then pure ()
  else tryError $ sformat ("checkNumber: expected number but got "%sh) dt

checkStrictDataType :: StrictDataType -> DataType -> Try ()
checkStrictDataType sdt dt =
  let sdt' = case dt of
          NullableType s -> s
          StrictType s -> s
  in if sdt == sdt'
     then pure ()
     else tryError $ sformat ("checkStrictDataType: expected type to be "%sh%" but got "%sh) sdt dt

checkStrictDataTypeList :: [StrictDataType] -> DataType -> Try ()
checkStrictDataTypeList [] _ = pure ()
checkStrictDataTypeList (h : t) dt = do
  _ <- checkStrictDataType h dt
  checkStrictDataTypeList t dt

colBuilder1 :: SqlFunctionName -> (DataType -> Try DataType) -> ColumnSQLBuilder
colBuilder1 n fun = ColumnSQLBuilder n f where
  f [dt] = fun dt
  f l = tryError $ sformat ("homoColBuilder1: Expected 1 input but got "%sh) l

colBuilder2 :: SqlFunctionName -> (DataType -> DataType -> Try DataType) -> ColumnSQLBuilder
colBuilder2 n f = ColumnSQLBuilder n f' where
  f' [dt1, dt2] = f dt1 dt2
  f' l = tryError $ sformat ("homoColBuilder2: Expected 2 inputs but got "%sh) l

colBuilder2Homo :: SqlFunctionName -> (DataType -> Try DataType) -> ColumnSQLBuilder
colBuilder2Homo n f = ColumnSQLBuilder n f' where
  f' [dt1, dt2] | dt1 == dt2 = f dt1
  f' [dt1, dt2] = tryError $ sformat ("homoColBuilder2: Expected types of both inputs to be equal: "%sh) (dt1, dt2)
  f' l = tryError $ sformat ("homoColBuilder2: Expected 2 inputs but got "%sh) l

refineColBuilderPost :: ColumnSQLBuilder -> (DataType -> Try DataType) -> ColumnSQLBuilder
refineColBuilderPost (ColumnSQLBuilder n f) f' = ColumnSQLBuilder n f'' where
  f'' x = f x >>= f'

_extraction' :: FieldPath -> DataType -> Try DataType
_extraction' fp = _extraction (V.toList (unFieldPath fp))

_extraction :: [FieldName] -> DataType -> Try DataType
_extraction [] dt = pure dt
_extraction (h : t) (StrictType (Struct st)) = _extractionStrict h t st NoNull
_extraction (h : t) (NullableType (Struct st)) = _extractionStrict h t st CanNull
_extraction l dt = tryError $ sformat ("_extraction:Cannot extract a subtype from "%sh%" given requested path "%sh) dt l

_extractionStrict :: FieldName -> [FieldName] -> StructType -> Nullable -> Try DataType
_extractionStrict h t (StructType v) nl = case find (\(StructField n _) -> n == h) (V.toList v) of
  Just (StructField _ dt) -> f <$> _extraction t dt where
    f (StrictType sdt) | nl == CanNull = NullableType sdt
    f dt' = dt'
  Nothing -> tryError $ sformat ("_extraction:Cannot find subfield called "%sh%" in struct "%sh) h v
