{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE OverloadedStrings #-}

module Spark.IO.Internal.InputGeneric(
  SparkPath(..),
  DataSchema(..),
  InputOptionValue(..),
  InputOptionKey(..),
  DataFormat(..),
  SourceDescription(..),
  generic',
  genericWithSchema',
  genericWithSchema
) where

import qualified Data.Map.Strict as M
import qualified Data.Text as T
import Data.Text(Text)
import Data.String(IsString(..))

import Spark.Core.Types
import Spark.Core.Context
import Spark.Core.Try
import Spark.Core.Dataset

import Spark.Core.Internal.Utilities(forceRight)
import Spark.Core.Internal.DatasetFunctions(asDF, emptyDataset, emptyLocalData)
import Spark.Core.Internal.TypesStructures(SQLType(..))
import Spark.Core.Internal.OpStructures
import qualified Proto.Karps.Proto.Io as PIO

{-| A path to some data that can be read by Spark.
-}
newtype SparkPath = SparkPath Text deriving (Show, Eq)

{-| The schema policty with respect to a data source. It should either
request Spark to infer the schema from the source, or it should try to
match the source against a schema provided by the user.
-}
data DataSchema = InferSchema | UseSchema DataType deriving (Show, Eq)

{-| The low-level option values accepted by the Spark reader API.
-}
data InputOptionValue =
    InputIntOption Int
  | InputDoubleOption Double
  | InputStringOption Text
  | InputBooleanOption Bool
  deriving (Eq, Show)

newtype InputOptionKey = InputOptionKey { unInputOptionKey :: Text } deriving (Eq, Show, Ord)

{-| The type of the source.

This enumeration contains all the data formats that are natively supported by
Spark, either for input or for output, and allows the users to express their
own format if requested.
-}
data DataFormat =
    JsonFormat
  | TextFormat
  | CsvFormat
  | CustomSourceFormat !Text
  deriving (Eq, Show)
-- data InputSource = JsonSource | TextSource | CsvSource | InputSource SparkPath

{-| A description of a data source, following Spark's reader API version 2.

Eeach source constists in an input source (json, xml, etc.), an optional schema
for this source, and a number of options specific to this source.

Since this descriptions is rather low-level, a number of wrappers of provided
for each of the most popular sources that are already built into Spark.
-}
data SourceDescription = SourceDescription {
  inputPath :: !SparkPath,
  inputSource :: !DataFormat,
  inputSchema :: !DataSchema,
  sdOptions :: !(M.Map InputOptionKey InputOptionValue),
  inputStamp :: !(Maybe DataInputStamp)
} deriving (Eq, Show)

instance IsString SparkPath where
  fromString = SparkPath . T.pack

{-| Generates a dataframe from a source description.

This may trigger some calculations on the Spark side if schema inference is
required.
-}
generic' :: SourceDescription -> SparkState DataFrame
generic' sd = do
  dtt <- _inferSchema sd
  return $ dtt >>= \dt -> genericWithSchema' dt sd

{-| Generates a dataframe from a source description, and assumes a given schema.

This schema overrides whatever may have been given in the source description. If
the source description specified that the schema must be checked or inferred,
this instruction is overriden.

While this is convenient, it may lead to runtime errors that are hard to
understand if the data does not follow the given schema.
-}
genericWithSchema' :: DataType -> SourceDescription -> DataFrame
genericWithSchema' dt sd = asDF $ emptyDataset no (SQLType dt) where
  sd' = sd { inputSchema = UseSchema dt }
  no = undefined
  -- so = StandardOperator {
  --     soName = "org.spark.GenericDatasource",
  --     soOutputType = dt,
  --     soExtra = A.toJSON sd'
  --   }
  -- no = NodeDistributedOp so

{-| Generates a dataframe from a source description, and assumes a certain
schema on the source.
-}
genericWithSchema :: forall a. (SQLTypeable a) => SourceDescription -> Dataset a
genericWithSchema sd =
  let sqlt = buildType :: SQLType a
      dt = unSQLType sqlt in
  forceRight $ castType sqlt =<< genericWithSchema' dt sd

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


-- Wraps the action of inferring the schema.
-- This is not particularly efficient here: it does a first pass to get the
-- schema, and then will do a second pass in order to read the data.
_inferSchema :: SourceDescription -> SparkState (Try DataType)
_inferSchema = executeCommand1 . _inferSchemaCmd

-- TODO: this is a monoidal operation, it could be turned into a universal
-- aggregator.
_inferSchemaCmd :: SourceDescription -> LocalData DataType
_inferSchemaCmd sd = emptyLocalData no sqlt where
  sqlt = buildType :: SQLType DataType
  no = undefined
  -- cniStandardOp
  -- dt = unSQLType sqlt
  -- so = StandardOperator {
  --     soName = "org.spark.InferSchema",
  --     soOutputType = dt,
  --     soExtra = _sou
  --   }
  -- no = NodeOpaqueAggregator so

_sourceDescriptionFromProto :: PIO.SourceDescription -> Try SourceDescription
_sourceDescriptionFromProto = undefined

_sourceDescriptionToProto :: SourceDescription -> PIO.SourceDescription
_sourceDescriptionToProto = undefined
