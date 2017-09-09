{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE TupleSections #-}

module Spark.Core.Internal.OpFunctions(
  simpleShowOp,
  prettyShowOp,
  extraNodeOpData,
  hashUpdateNodeOp,
  prettyShowColOp,
  hdfsPath,
  updateSourceStamp,
  prettyShowColFun,
  -- Serialization
  aggOpToProto,
  aggOpFromProto,
  colOpToProto,
  colOpFromProto,
  -- Basic builders:
  -- pointerBuilder,
) where

import qualified Crypto.Hash.SHA256 as SHA
import qualified Data.Text as T
import qualified Data.Vector as V
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as LBS
import qualified Data.HashMap.Strict as HM
import Control.Monad(join)
import Data.Text.Encoding(encodeUtf8)
import Data.Text(Text)
import Data.Char(isSymbol)
import Data.ProtoLens.Message(def)
import Formatting
import Lens.Family2 ((&), (.~), (^.))

import qualified Spark.Core.Internal.OpStructures as OS
import Spark.Core.Internal.OpStructures
import Spark.Core.Internal.Utilities
import Spark.Core.Internal.NodeBuilder
import Spark.Core.Internal.TypesFunctions(arrayType')
import Spark.Core.StructuresInternal(FieldName(..), FieldPath(..), fieldPathToProto, unFieldName, fieldPathFromProto)
import Spark.Core.Try
import Proto.Karps.Proto.StructuredTransform
import qualified Proto.Karps.Proto.StructuredTransform as P


-- (internal)
-- The serialized type of a node operation, as written in
-- the JSON and proto description.
simpleShowOp :: NodeOp -> T.Text
simpleShowOp (NodeLocalOp op') = soName op'
simpleShowOp (NodeDistributedOp op') = soName op'
simpleShowOp (NodeLocalLit _ _) = "org.spark.LocalLiteral"
simpleShowOp (NodeOpaqueAggregator op') = soName op'
simpleShowOp (NodeAggregatorReduction ua) =
  _jsonShowAggTrans . uaoInitialOuter $ ua
simpleShowOp (NodeAggregatorLocalReduction ua) = _jsonShowSGO . uaoMergeBuffer $ ua
simpleShowOp (NodeStructuredTransform _) = "org.spark.Select"
simpleShowOp (NodeLocalStructuredTransform _) = "org.spark.LocalStructuredTransform"
simpleShowOp (NodeDistributedLit _ _) = "org.spark.DistributedLiteral"
simpleShowOp (NodeGroupedReduction _) = "org.spark.GroupedReduction"
simpleShowOp (NodeReduction _) = "org.spark.Reduction"
simpleShowOp NodeBroadcastJoin = "org.spark.BroadcastJoin"
simpleShowOp (NodePointer _) = "org.spark.PlaceholderCache"

{-| A text representation of the operation that is appealing for humans.
-}
prettyShowOp :: NodeOp -> T.Text
prettyShowOp (NodeAggregatorReduction uao) =
  case uaoInitialOuter uao of
    OpaqueAggTransform so -> soName so
    -- Try to have a pretty name for the simple reductions
    InnerAggOp (AggFunction n _) -> n
    _ -> simpleShowOp (NodeAggregatorReduction uao)
prettyShowOp x = simpleShowOp x


-- A human-readable string that represents column operations.
prettyShowColOp :: ColOp -> T.Text
prettyShowColOp (ColExtraction fpath) = T.pack (show fpath)
prettyShowColOp (ColFunction txt cols) =
  prettyShowColFun txt (V.toList (prettyShowColOp <$> cols))
prettyShowColOp (ColLit _ cell) = show' cell
prettyShowColOp (ColStruct s) =
  "struct(" <> T.intercalate "," (prettyShowColOp . tfValue <$> V.toList s) <> ")"

{-| If the node is a reading operation, returns the HdfsPath of the source
that is going to be read.
-}
hdfsPath :: NodeOp -> Maybe HdfsPath
hdfsPath (NodeDistributedOp so) =
  -- TODO: move this to IO: it needs to unpack the IO node extra info and
  -- find the path there
  error "hdfsPath: not implemented"
--   if soName so == "org.spark.GenericDatasource"
--   then case soExtra so of
--     A.Object o -> case HM.lookup "inputPath" o of
--       Just (A.String x) -> Just . HdfsPath $ x
--       _ -> Nothing
--     _ -> Nothing
--   else Nothing
-- hdfsPath _ = Nothing

{-| Updates the input stamp if possible.

If the node cannot be updated, it is most likely a programming error: an error
is returned.
-}
updateSourceStamp :: NodeOp -> DataInputStamp -> Try NodeOp
updateSourceStamp (NodeDistributedOp so) (DataInputStamp dis) | soName so == "org.spark.GenericDatasource" =
  -- TODO: move this to IO: it needs to unpack the IO node extra info and
  -- find the path there
  error "updateSourceStamp: not implemented"
--   case soExtra so of
--     A.Object o ->
--       let extra' = A.Object $ HM.insert "inputStamp" (A.toJSON dis) o
--           so' = so { soExtra = extra' }
--       in pure $ NodeDistributedOp so'
--     x -> tryError $ "updateSourceStamp: Expected dict, got " <> show' x
-- updateSourceStamp x _ =
--   tryError $ "updateSourceStamp: Expected NodeDistributedOp, got " <> show' x

-- pointerBuilder :: NodeBuilder
-- pointerBuilder = buildOpExtra "org.spark.PlaceholderCache" $ \(p @ (Pointer _ _ shp)) ->
--   return $ CoreNodeInfo shp (NodePointer p)


_jsonShowAggTrans :: AggTransform -> Text
_jsonShowAggTrans (OpaqueAggTransform op') = soName op'
_jsonShowAggTrans (InnerAggOp _) = "org.spark.StructuredReduction"


_jsonShowSGO :: SemiGroupOperator -> Text
_jsonShowSGO (OpaqueSemiGroupLaw so) = soName so
_jsonShowSGO (UdafSemiGroupOperator ucn) = ucn
_jsonShowSGO (ColumnSemiGroupLaw sfn) = sfn


_prettyShowAggOp :: AggOp -> T.Text
_prettyShowAggOp (AggUdaf _ ucn fp) = ucn <> "(" <> show' fp <> ")"
_prettyShowAggOp (AggFunction sfn v) = prettyShowColFun sfn r where
  r = [show' v]
_prettyShowAggOp (AggStruct v) =
  "struct(" <> T.intercalate "," (_prettyShowAggOp . afValue <$> V.toList v) <> ")"

_prettyShowAggTrans :: AggTransform -> Text
_prettyShowAggTrans (OpaqueAggTransform op') = soName op'
_prettyShowAggTrans (InnerAggOp ao) = _prettyShowAggOp ao

_prettyShowSGO :: SemiGroupOperator -> Text
_prettyShowSGO (OpaqueSemiGroupLaw so) = soName so
_prettyShowSGO (UdafSemiGroupOperator ucn) = ucn
_prettyShowSGO (ColumnSemiGroupLaw sfn) = sfn

-- (internal)
-- The extra data associated with the operation, and that is required
-- by the backend to successfully perform the operation.
-- We pass the type as seen by Karps (along with some extra information about
-- nullability). This information is required by spark to analyze the exact
-- type of some operations.
extraNodeOpData :: NodeOp -> OpExtra
-- TODO This should be done directly by looking at the extra info of the node.
extraNodeOpData = error "extraNodeOpData"
-- extraNodeOpData (NodeLocalLit dt cell) =
--   A.object [ "cellType" .= toJSON dt,
--              "cell" .= toJSON cell]
-- extraNodeOpData (NodeStructuredTransform st) = toJSON st
-- extraNodeOpData (NodeLocalStructuredTransform st) = toJSON st
-- extraNodeOpData (NodeDistributedLit dt lst) =
--   -- The backend deals with all the details translating the augmented type
--   -- as a SQL datatype.
--   A.object [ "cellType" .= toJSON (arrayType' dt),
--              "cell" .= A.object [
--               "arrayValue" .= A.object [
--                 "values" .= toJSON lst]]]
-- extraNodeOpData (NodeDistributedOp so) = soExtra so
-- extraNodeOpData (NodeGroupedReduction ao) = toJSON ao
-- extraNodeOpData (NodeAggregatorReduction ua) =
--   case uaoInitialOuter ua of
--     OpaqueAggTransform so -> toJSON (soExtra so)
--     InnerAggOp ao -> toJSON ao
-- extraNodeOpData (NodeOpaqueAggregator so) = soExtra so
-- extraNodeOpData (NodeLocalOp so) = soExtra so
-- extraNodeOpData NodeBroadcastJoin = A.Null
-- extraNodeOpData (NodeReduction _) = A.Null -- TODO: should it send something?
-- extraNodeOpData (NodeAggregatorLocalReduction _) = A.Null -- TODO: should it send something?
-- extraNodeOpData (NodePointer p) =
--     A.object [
--       "computation" .= toJSON (computation p),
--       "localPath" .= toJSON (OS.path p)
--     ]

-- Adds the content of a node op to a hash.
-- Right now, this builds the json representation and passes it
-- to the hash function, which simplifies the verification on
-- on the server side.
-- TODO: this depends on some implementation details such as the hashing
-- function used by Aeson.
hashUpdateNodeOp :: SHA.Ctx -> NodeOp -> SHA.Ctx
hashUpdateNodeOp ctx op' = error "hashUpdateNodeOp"
  -- _hashUpdateJson ctx $ A.object [
  --   "op" .= simpleShowOp op',
  --   "extra" .= extraNodeOpData op']


prettyShowColFun :: T.Text -> [Text] -> T.Text
prettyShowColFun txt [col] | _isSym txt =
  T.concat [txt, " ", col]
prettyShowColFun txt [col1, col2] | _isSym txt =
  -- This is not perfect for complex operations, but it should get the job done
  -- for now.
  -- TODO eventually use operator priority here
  T.concat [col1, " ", txt, " ", col2]
prettyShowColFun txt cols =
  let vals = T.intercalate ", " cols in
  T.concat [txt, "(", vals, ")"]

_isSym :: T.Text -> Bool
_isSym txt = all isSymbol (T.unpack txt)

colOpToProto :: ColOp -> Column
colOpToProto = _colOpToProto Nothing

_colOpToProto :: Maybe FieldName -> ColOp -> Column
_colOpToProto _ (ColLit _ _) = error "_colOpToProto: literal"
_colOpToProto fn (ColExtraction (FieldPath l)) =
  _colProto fn & P.extraction .~ e where
    e = (def :: ColumnExtraction) & P.path .~ V.toList (unFieldName <$> l)
_colOpToProto fn (ColFunction txt cols) =
  _colProto fn & P.function .~ f where
    l = V.toList (_colOpToProto Nothing <$> cols)
    f = (def :: ColumnFunction)
          & P.functionName .~ txt
          & P.inputs .~ l
_colOpToProto fn (ColStruct v) =
  _colProto fn & P.struct .~ s where
    s = (def :: ColumnStructure) & P.fields .~ l
    f (TransformField fn' co) = _colOpToProto (Just fn') co
    l = V.toList (f <$> v)

_colProto :: Maybe FieldName -> Column
_colProto (Just fn) = def & P.fieldName .~ unFieldName fn
_colProto Nothing = def

colOpFromProto :: Column -> Try ColOp
colOpFromProto c = snd <$> _fromProto' c where
  _structFromProto :: ColumnStructure -> Try ColOp
  _structFromProto (ColumnStructure l) =
    ColStruct . V.fromList <$> l2 where
      l' = sequence (_fromProto' <$> l)
      f (Nothing, _) = tryError $ sformat ("colOpFromProto: found a field with no name "%sh) l
      f (Just fn, co) = pure $ TransformField fn co
      l'' = (f <$>) <$> l'
      l2 = join (sequence <$> l'')
  _funFromProto :: ColumnFunction -> Try ColOp
  _funFromProto (ColumnFunction fname l) = ColFunction fname <$> x where
      l2 = _fromProto' <$> V.fromList l
      x = (snd <$>) <$> sequence l2
  _fromProto :: Column'Content -> Try ColOp
  _fromProto (Column'Struct cs) = _structFromProto cs
  _fromProto (Column'Function f) = _funFromProto f
  _fromProto (Column'Extraction ce) =
    pure . ColExtraction . fieldPathFromProto $ ce
  _fromProto' :: Column -> Try (Maybe FieldName, ColOp)
  _fromProto' c' = do
    x <- case c' ^. P.maybe'content of
      Just con -> _fromProto con
      Nothing -> tryError $ sformat ("colOpFromProto: cannot understand column struture "%sh) c'
    let l = case c' ^. P.fieldName of
              x' | x' == "" -> Nothing
              x' -> Just x'
    return (FieldName <$> l, x)


aggOpToProto :: AggOp -> Aggregation
aggOpToProto AggUdaf{} = error "_aggOpToProto: not implemented: AggUdaf"
aggOpToProto (AggFunction sfn v) =
  (def :: Aggregation) & P.op .~ x where
    x = (def :: AggregationFunction)
        & P.functionName .~ sfn
        & inputs .~ [fieldPathToProto v]
aggOpToProto (AggStruct v) =
  (def :: Aggregation) & P.struct .~ x where
    f :: AggField -> Aggregation
    f (AggField n v') = (aggOpToProto v') & P.fieldName .~ unFieldName n
    x = (def :: AggregationStructure) & P.fields .~ (f <$> V.toList v)

aggOpFromProto :: Aggregation -> Try AggOp
aggOpFromProto = snd . _aggOpFromProto

_aggOpFromProto :: Aggregation -> (Maybe FieldName, Try AggOp)
_aggOpFromProto a =  (f, y) where
  f1 = a ^. P.fieldName
  f = if f1 == "" then Nothing else Just (FieldName f1)
  y = case a ^. P.maybe'aggOp of
      Nothing -> tryError $ sformat ("_aggOpFromProto: deserialization failed: missing op on "%sh) a
      Just (Aggregation'Op af) -> _aggFunFromProto af
      Just (Aggregation'Struct s) -> _aggStructFromProto s

_aggFunFromProto :: AggregationFunction -> Try AggOp
_aggFunFromProto (AggregationFunction sfn [fpp]) =
  pure $ AggFunction sfn (fieldPathFromProto fpp)
_aggFunFromProto x = tryError $ sformat ("_aggFunFromProto: deserialization failed on "%sh) x

_aggStructFromProto :: AggregationStructure -> Try AggOp
_aggStructFromProto (AggregationStructure l) =   AggStruct . V.fromList <$> v where
    f (Just fn, x) = AggField <$> pure fn <*> x
    f x = tryError $ sformat ("_aggStructFromProto: deserialization failed on "%sh) x
    v = sequence (f . _aggOpFromProto <$> l)


-- _field :: A.ToJSON a => a -> A.Value
-- _field fp = A.object ["path" .= fp]

-- _hashUpdateJson :: SHA.Ctx -> A.Value -> SHA.Ctx
-- _hashUpdateJson = undefined
-- _hashUpdateJson ctx val = SHA.update ctx bs where
--   bs = BS.concat . LBS.toChunks . encodeDeterministicPretty $ val
