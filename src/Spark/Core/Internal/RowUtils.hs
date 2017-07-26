{-# LANGUAGE OverloadedStrings #-}

module Spark.Core.Internal.RowUtils(
  jsonToCell,
  checkCell,
  rowArray,
  rowCell
) where

import Data.Aeson
import Data.Text(Text)
import Data.Maybe(catMaybes, listToMaybe)
import Formatting
import qualified Data.Vector as V
import qualified Data.HashMap.Strict as HM
import Data.Scientific(floatingOrInteger, toRealFloat)
import Control.Monad.Except

import Spark.Core.Internal.TypesStructures
import Spark.Core.Internal.TypesFunctions
import Spark.Core.Internal.RowStructures
import Spark.Core.StructuresInternal(FieldName(..))
import Spark.Core.Internal.Utilities

type TryCell = Either Text Cell

-- | Decodes a JSON into a row.
-- This operation requires a SQL type that describes
 -- the schema.
jsonToCell :: DataType -> Value -> Either Text Cell
jsonToCell dt v = withContext ("jsonToCell: dt="<>show' dt<>" v="<>show' v) $
  _j2Cell v dt

{-| Given a datatype, ensures that the cell has the corresponding type.
-}
checkCell :: DataType -> Cell -> Either Text Cell
checkCell dt c = case _checkCell dt c of
  Nothing -> pure c
  Just txt -> throwError txt

{-| Convenience constructor for an array of cells.
-}
rowArray :: [Cell] -> Cell
rowArray = RowArray . V.fromList

rowCell :: [Cell] -> Cell
rowCell = RowElement . Row . V.fromList

-- Returns an error message if something wrong is found
_checkCell :: DataType -> Cell -> Maybe Text
_checkCell dt c = case (dt, c) of
  (NullableType _, Empty) -> Nothing
  (StrictType _, Empty) ->
    pure $ sformat ("Expected a strict value of type "%sh%" but no value") dt
  (StrictType sdt, x) -> _checkCell' sdt x
  (NullableType sdt, x) -> _checkCell' sdt x

-- Returns an error message if something wrong is found
_checkCell' :: StrictDataType -> Cell -> Maybe Text
_checkCell' sdt c = case (sdt, c) of
  (_, Empty) ->
    pure $ sformat ("Expected a strict value of type "%sh%" but no value") sdt
  (IntType, IntElement _) -> Nothing
  (StringType, StringElement _) -> Nothing
  (Struct s, RowElement (Row l)) -> _checkCell' (Struct s) (RowArray l)
  (Struct (StructType fields), RowArray cells') ->
    if V.length fields == V.length cells'
      then
        let types = V.toList $ structFieldType <$> fields
            res = uncurry _checkCell <$> (types `zip` V.toList cells')
        in listToMaybe (catMaybes res)
      else
        pure $ sformat ("Struct "%sh%" has "%sh%" fields, asked to be matched with "%sh%" cells") sdt (V.length fields) (V.length cells')
  (ArrayType dt, RowArray cells') ->
    let res = uncurry _checkCell <$> (repeat dt `zip` V.toList cells')
    in listToMaybe (catMaybes res)
  (_, _) ->
    pure $ sformat ("Type "%sh%" is incompatible with cell content "%sh) sdt c


_j2Cell :: Value -> DataType -> TryCell
_j2Cell Null (StrictType t) =
  throwError $ sformat ("_j2Cell: Expected "%shown%", got null") t
_j2Cell Null (NullableType _) = pure Empty
_j2Cell (Object o) dt =
  let t = case dt of
        StrictType t' -> t'
        NullableType t' -> t'
      isNullable_ = case dt of
        StrictType _ -> False
        NullableType _ -> True
  in case (HM.toList o, t) of
    ([], _) | isNullable_ -> pure Empty
    ([(n, Number x)], IntType) | n == "intValue" ->
      case floatingOrInteger x :: Either Double Int of
        Left _ -> throwError $ sformat ("_j2Cell: Could not cast as int "%shown) x
        Right i -> pure (IntElement i)
    ([(n, String x)], StringType) | n == "stringValue" ->
      pure . StringElement $ x
    ([(n, Bool x)], BoolType) | n == "boolValue" ->
      pure . BoolElement $ x
    ([(n, Number x)], DoubleType) | n == "doubleValue" ->
      pure . DoubleElement . toRealFloat $ x
    ([(n, Object x)], ArrayType at) | n == "arrayValue" ->
      case HM.lookup "values" x of
        -- It could be a default empty value
        Nothing -> return (RowArray V.empty)
        Just (Array v) ->
          let trys = flip _j2Cell at <$> v in
            RowArray <$> sequence trys
        Just y ->
          throwError $ sformat ("_j2Cell:array: Expected array, got "%sh) y
    ([(n, Object x)], Struct (StructType fields)) | n == "structValue" ->
      case HM.lookup "values" x of
        -- It could be a default empty value
        Nothing -> return (RowArray V.empty)
        Just (Array v) | V.length v == V.length fields ->
          let ftypes = structFieldType <$> fields
              trys = uncurry _j2Cell <$> (v `V.zip` ftypes) in
            RowElement . Row <$> sequence trys
        Just (Array v) ->
          throwError $ sformat ("_j2Cell:struct: Got "%sh%" elements but type fields are"%sh) (V.length v) fields
        Just y ->
          throwError $ sformat ("_j2Cell:struct: Expected array, got "%sh) y
    ([(fname, fval)], _) -> throwError $ sformat ("_j2Cell: Unrecognized field "%sh%"->"%sh%" for expected type"%sh) fname fval dt
    (l, _) -> throwError $ sformat ("_j2Cell: Expected one element, got "%shown) l
_j2Cell x dt = _j2CellS x t where
  t = case dt of
    StrictType t' -> t'
    NullableType t' -> t'
-- We do not express optional types at cell level. They have to be
-- encoded in the data type.
-- _j2Cell x (NullableType t) = _j2CellS x t
--_j2Cell x t = throwError $ sformat ("_j2Cell: Could not match value "%shown%" with type "%shown) x t

_j2CellS :: Value -> StrictDataType -> TryCell
_j2CellS (String t) StringType = pure . StringElement $ t
_j2CellS (Bool t) BoolType = pure . BoolElement $ t
_j2CellS (Array v) (ArrayType t) =
  let trys = flip _j2Cell t <$> v in
    RowArray <$> sequence trys
_j2CellS (Number s) IntType = case floatingOrInteger s :: Either Double Int of
  Left _ -> throwError $ sformat ("_j2CellS: Could not cast as int "%shown) s
  Right i -> pure (IntElement i)
_j2CellS (Number s) DoubleType = pure . DoubleElement . toRealFloat $ s
-- Normal representation as object.
_j2CellS (Object o) (Struct struct) =
  let
    o2f :: StructField -> TryCell
    o2f field =
      let nullable = isNullable $ structFieldType field
          val = HM.lookup (unFieldName $ structFieldName field) o in
      case val of
        Nothing ->
          if nullable then
            pure Empty
          else throwError $ sformat ("_j2CellS: Could not find key "%shown%" in object "%shown) field o
        Just x -> _j2Cell x (structFieldType field)
    fields = o2f <$> structFields struct
  in RowArray <$> sequence fields
-- Compact array-based representation.
_j2CellS (Array v) (Struct (StructType fields)) =
  if V.length v == V.length fields
    then
      let dts = structFieldType <$> fields
          inner = uncurry _j2Cell <$> V.zip v dts
      in RowArray <$> sequence inner
    else throwError $ sformat ("_j2CellS: Compact object format a different number of fields '"%shown%"' compared "%shown) v fields
_j2CellS x t = throwError $ sformat ("_j2CellS: Could not match value '"%shown%"' with type "%shown) x t
