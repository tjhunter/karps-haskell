{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}

{-|
A description of the operations that can be performed on
nodes and columns.
-}
module Spark.Core.Internal.OpStructures(
  SqlFunctionName,
  UdafClassName,
  UdfClassName,
  OperatorName,
  HdfsPath(..),
  DataInputStamp(..),
  Locality(..),
  StandardOperator(..),
  NodeShape(..),
  CoreNodeInfo(..),
  -- CoreNodeBuilder,
  ColOp(..),
  TransformField(..),
  StructuredTransform(..),
  UdafApplication(..),
  AggOp(..),
  AggField(..),
  AggTransform(..),
  SemiGroupOperator(..),
  UniversalAggregatorOp(..),
  Pointer(..),
  NodeOp(..),
  OpExtra(..),
  makeOperator,
  coreNodeInfo,
  emptyExtra
) where

import Data.Text as T
import GHC.Generics (Generic)
import Data.Aeson(Value, Value(Null), FromJSON, ToJSON, toJSON)
import Data.Aeson.Types(typeMismatch)
import Data.ByteString(ByteString)
-- import qualified Data.Aeson as A
import Data.Vector(Vector)

-- import Proto.Karps.Proto.Graph(OpExtra(..))
import Spark.Core.StructuresInternal
import Spark.Core.Internal.ProtoUtils
import Spark.Core.Internal.RowStructures(Cell)
import Spark.Core.Internal.TypesStructures(DataType, SQLType, SQLType(unSQLType))
import Spark.Core.Try
import qualified Proto.Karps.Proto.Graph as PG
import qualified Proto.Karps.Proto.ApiInternal as PAI

{-| The name of a SQL function.

It is one of the predefined SQL functions available in Spark.
-}
type SqlFunctionName = T.Text

{-| The classpath of a UDAF.
-}
type UdafClassName = T.Text

{-| The name of a UDF.
-}
type UdfClassName = T.Text

{-| The name of an operator defined in Karps.
-}
type OperatorName = T.Text

{-| A path in the Hadoop File System (HDFS).

These paths are usually not created by the user directly.
-}
data HdfsPath = HdfsPath Text deriving (Eq, Show, Ord)

data OpExtra = OpExtra ByteString deriving (Eq, Show)

emptyExtra :: OpExtra
emptyExtra = OpExtra ""

{-| A stamp that defines some notion of uniqueness of the data source.

The general contract is that:
 - stamps can be extracted fast (no need to scan the whole dataset)
 - if the data gets changed, the stamp will change.

Stamps are used for performing aggressing operation caching, so it is better
to conservatively update stamps if one is unsure about the freshness of the
dataset. For regular files, stamps are computed using the file system time
stamps.
-}
data DataInputStamp = DataInputStamp Text deriving (Eq, Show)


-- {-| The invariant respected by a transform.
--
-- Depending on the value of the invariant, different optimizations
-- may be available.
-- -}
-- data TransformInvariant =
--     -- | This operator has no special property. It may depend on
--     -- the partitioning layout, the number of partitions, the order
--     -- of elements in the partitions, etc.
--     -- This sort of operator is unwelcome in Karps...
--     Opaque
--     -- | This operator respects the canonical partition order, but may
--     -- not have the same number of elements.
--     -- For example, this could be a flatMap on an RDD (filter, etc.).
--     -- This operator can be used locally with the signature a -> [a]
--   | PartitioningInvariant
--     -- | The strongest invariant. It respects the canonical partition order
--     -- and it outputs the same number of elements.
--     -- This is typically a map.
--     -- This operator can be used locally with the signature a -> a
--   | DirectPartitioningInvariant

data Locality = Local | Distributed deriving (Eq, Show)

-- ********* PHYSICAL OPERATORS ***********
-- These structures declare some operations that correspond to operations found
-- in Spark itself, or in the surrounding libraries.

-- | An operator defined by default in the release of Karps.
-- All other physical operators can be converted to a standard operators.
data StandardOperator = StandardOperator {
  soName :: !OperatorName,
  soOutputType :: !DataType,
  soExtra :: !OpExtra
} deriving (Eq, Show)

-- -- | A scala method of a singleton object.
-- data ScalaStaticFunctionApplication = ScalaStaticFunctionApplication {
--   sfaObjectName :: !T.Text,
--   sfaMethodName :: !T.Text
--   -- TODO add the input and output types?
-- }

{-| The outside information of a node.

The is the visible information about a node, and the
only one that should matter when assembling a graph.
-}
-- TODO this is encoded is a proto
data NodeShape = NodeShape {
  nsType :: !DataType, -- TODO rename nodeType
  nsLocality :: !Locality -- TODO rename locality
} deriving (Eq, Show)

{-| The core information that characterizes a node
(except for the the topological information).

A graph of computation can be reduced to core info and
DAG informations.
-}
data CoreNodeInfo = CoreNodeInfo {
  cniShape :: !NodeShape,
  cniOp :: !NodeOp
} deriving (Eq, Show)

coreNodeInfo :: DataType -> Locality -> NodeOp -> CoreNodeInfo
coreNodeInfo dt loc op =
    CoreNodeInfo {
      cniShape = NodeShape {
        nsType = dt,
        nsLocality = loc
      },
      cniOp = op
    }

-- TODO: remove
-- type CoreNodeBuilder = OpExtra -> [NodeShape] -> Try CoreNodeInfo

-- | The different kinds of column operations that are understood by the
-- backend.
--
-- These operations describe the physical operations on columns as supported
-- by Spark SQL. They can operate on column -> column, column -> row, row->row.
-- Of course, not all operators are valid for each configuration.
data ColOp =
    -- | A projection onto a single column
    -- An extraction is always direct.
    ColExtraction !FieldPath
    -- | A function of other columns.
    -- In this case, the other columns may matter
    -- TODO(kps) add if this function is partition invariant.
    -- It should be the case most of the time.
  | ColFunction !SqlFunctionName !(Vector ColOp)
    -- | A constant defined for each element.
    -- The type should be the same as for the column
    -- A literal is always direct
  | ColLit !DataType !Cell
    -- | A structure.
    -- TODO: have a function for constructor with NonEmpty
  | ColStruct !(Vector TransformField)
  deriving (Eq, Show)

-- | A field in a structure.
data TransformField = TransformField {
  tfName :: !FieldName,
  tfValue :: !ColOp
} deriving (Eq, Show)

-- | The content of a structured transform.
data StructuredTransform =
    InnerOp !ColOp
  | InnerStruct !(Vector TransformField)
  deriving (Eq, Show)

{-| When applying a UDAF, determines if it should only perform the algebraic
portion of the UDAF (initialize+update+merge), or if it also performs the final,
non-algebraic step.
-}
data UdafApplication = Algebraic | Complete deriving (Eq, Show)

data AggOp =
    -- The name of the UDAF and the field path to apply it onto.
    AggUdaf !UdafApplication !UdafClassName !FieldPath
    -- A column function that can be applied (sum, max, etc.)
  | AggFunction !SqlFunctionName !FieldPath
  | AggStruct !(Vector AggField)
  deriving (Eq, Show)

{-| A field in the resulting aggregation transform.
-}
data AggField = AggField {
  afName :: !FieldName,
  afValue :: !AggOp
} deriving (Eq, Show)

{-| The different sorts of aggregations supported in the engine.
-}
data AggTransform =
    OpaqueAggTransform !StandardOperator
  | InnerAggOp !AggOp deriving (Eq, Show)

{-| The representation of a semi-group law in Spark.

This is the basic law used in universal aggregators. It is a function on
observables that must respect the following laws:

f :: X -> X -> X
commutative
associative

A neutral element is not required for the semi-group laws. However, if used in
the context of a universal aggregator, such an element implicitly exists and
corresponds to the empty dataset.
-}
data SemiGroupOperator =
    -- | A standard operator that happens to respect the semi-group laws.
    OpaqueSemiGroupLaw !StandardOperator
    -- | The merging portion of a UDAF
  | UdafSemiGroupOperator !UdafClassName
    -- | A SQL operator that happens to respect the semi-group laws.
  | ColumnSemiGroupLaw !SqlFunctionName deriving (Eq, Show)

-- ********* DATASET OPERATORS ************
-- These describe Dataset -> Dataset transforms.


-- data DatasetTransformDesc =
--     DSScalaStaticFunction !ScalaStaticFunctionApplication
--   | DSStructuredTransform !ColOp
--   | DSOperator !StandardOperator


-- ****** OBSERVABLE OPERATORS *******
-- These operators describe Observable -> Observable transforms

-- **** AGGREGATION OPERATORS *****
-- The different types of aggregators

-- The low-level description of a
-- The name of the aggregator is the name of the
-- Dataset -> Local data transform
data UniversalAggregatorOp = UniversalAggregatorOp {
  uaoMergeType :: !DataType,
  uaoInitialOuter :: !AggTransform,
  uaoMergeBuffer :: !SemiGroupOperator
} deriving (Eq, Show)

-- TODO: remove the data types, they are carried at the core
-- TODO: remove the locality, carried at the core.
data NodeOp2 =
  -- empty -> local
    NodeLocalLiteral !DataType !Cell
  -- empty -> distributed
  | NodeDistributedLiteral !DataType !(Vector Cell)
  -- distributed -> local
  | NodeStructuredAggregation !AggOp !(Maybe UniversalAggregatorOp)
  -- distributed -> distributed or local -> local
  | NodeStructuredTransform2 !Locality !ColOp
  -- [distributed, local] -> [local, distributed] opaque
  | NodeOpaqueTransform !Locality StandardOperator
  deriving (Eq, Show)

{-| A pointer to a node that is assumed to be already computed.
-}
data Pointer = Pointer {
  computation :: !ComputationID,
  path :: !NodePath,
  shape :: !NodeShape
} deriving (Eq, Show)

{-
A node operation.
A description of all the operations between nodes.
These are the low-level, physical operations that Spark implements.

Each node operation is associated with:
 - a locality
 - an operation name (implicit or explicit)
 - a data type
 - a representation in JSON

Additionally, some operations are associated with algebraic invariants
to enable programmatic transformations.
-}
-- TODO: way too many different ops. Restructure into a few fundamental ops with
-- options.
data NodeOp =
    -- | An operation between local nodes: [Observable] -> Observable
    NodeLocalOp StandardOperator
    -- | An observable literal
  | NodeLocalLit !DataType !Cell
    -- | A special join that broadcasts a value along a dataset.
  | NodeBroadcastJoin
    -- | Some aggregator that does not respect any particular invariant.
  | NodeOpaqueAggregator StandardOperator
    -- It implicicty expects a dataframe with 2 fields:
    --  - the first field is used as a key
    --  - the second field is passed to the reducer
  | NodeGroupedReduction !AggOp
  | NodeReduction !AggTransform
    -- TODO: remove these
    -- | A universal aggregator.
  | NodeAggregatorReduction UniversalAggregatorOp
  | NodeAggregatorLocalReduction UniversalAggregatorOp
    -- | A structured transform, performed either on a local node or a
    -- distributed node.
  | NodeStructuredTransform !ColOp
  | NodeLocalStructuredTransform !ColOp
    -- | A distributed dataset (with no partition information)
  | NodeDistributedLit !DataType !(Vector Cell)
    -- | An opaque distributed operator.
  | NodeDistributedOp StandardOperator
  | NodePointer Pointer
  deriving (Eq, Show)

-- | Makes a standard operator with no extra value
makeOperator :: T.Text -> SQLType a -> StandardOperator
makeOperator txt sqlt =
  StandardOperator {
    soName = txt,
    soOutputType = unSQLType sqlt,
    soExtra = emptyExtra  }

instance ToProto PG.Locality Locality where
  toProto Distributed = PG.DISTRIBUTED
  toProto Local = PG.LOCAL

instance FromProto PG.OpExtra OpExtra where
  fromProto (PG.OpExtra x) = pure (OpExtra x)

instance ToProto PG.OpExtra OpExtra where
  toProto (OpExtra x) = PG.OpExtra x
