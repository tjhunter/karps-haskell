{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TypeFamilies #-}

module Spark.Core.Internal.DatasetStructures where

import Control.Arrow ((&&&))
import Data.Function(on)
import Data.Vector(Vector)

import Spark.Core.StructuresInternal
import Spark.Core.Try
import Spark.Core.Row
import Spark.Core.Internal.OpStructures
import Spark.Core.Internal.TypesStructures

-- !!!!!
-- TODO: split TopNode into a separate file, and add
-- all the basic functions (nodeId, parents, etc.) into a file
-- This way, we just need to scope the changes to the other files.

{-| (internal) The constructor for the top-level structures.

This contains the full information, and forms DAGS.

This type is internal and should not be used. Use ComputeNode instead.
-}
-- TODO: separate the topology info from the node info (TopNodeData). It will help when
-- building the graphs.
data TopNode loc a = TopNode {
  -- | The id of the node.
  --
  -- Non strict because it may be expensive.
  _cnNodeId :: NodeId,
  -- The following fields are used to build a unique ID to
  -- a compute node:

  -- | The operation associated to this node.
  _cnOp :: !NodeOp,
  -- | The type of the node
  _cnType :: !DataType,
  -- | The direct parents of the node. The order of the parents is important
  -- for the semantics of the operation.
  -- TODO(tjh) replace with ComputeNodeCons
  _cnParents :: !(Vector UntypedTopNode),
  -- | A set of extra dependencies that can be added to force an order between
  -- the nodes.
  --
  -- The order is not important, they are sorted by ID.
  --
  -- TODO(kps) add this one to the id
  -- TODO(tjh) replace with ComputeNodeCons
  _cnLogicalDeps :: !(Vector UntypedTopNode),
  -- | The locality of this node.
  --
  -- TODO(kps) add this one to the id
  _cnLocality :: !Locality,
  -- Attributes that are not included in the id
  -- These attributes are mostly for the user to relate to the nodes.
  -- They are not necessary for the computation.
  --
  -- | The name
  _cnName :: !(Maybe NodeName),
  -- | A set of nodes considered as the logical input for this node.
  -- This has no influence on the calculation of the id and is used
  -- for organization purposes only.
  -- TODO(tjh) replace with ComputeNodeCons
  _cnLogicalParents :: !(Maybe (Vector UntypedTopNode)),
  -- | The path of this oned in a computation flow.
  --
  -- This path includes the node name.
  -- Not strict because it may be expensive to compute.
  -- By default it only contains the name of the node (i.e. the node is
  -- attached to the root)
  _cnPath :: NodePath
} deriving (Eq)

type UntypedTopNode = TopNode LocUnknown Cell

{-| The data structure that implements the notion of data columns.

The type on this one may either be a Cell or a proper type.

A column of data from a dataset
The ref is a reference potentially to the originating
dataset, but it may be more general than that to perform
type-safe tricks.

Unlike Spark, columns are always attached to a reference dataset or dataframe.
One cannot materialize a column out of thin air. In order to broadcast a value
along a given column, the `broadcast` function is provided.

TODO: try something like this https://www.vidarholen.net/contents/junk/catbag.html
-}
data ColumnData = ColumnData {
  _cOrigin :: !UntypedDataset,
  _cType :: !DataType,
  _cOp :: !GeneralizedColOp,
  -- The name in the dataset.
  -- If not set, it will be deduced from the operation.
  _cReferingPath :: !(Maybe FieldName)
}


{-| (internal) The main data structure that represents a data node in the
computation graph.

This data structure forms the backbone of computation graphs expressed
with spark operations.

loc is a typed locality tag.
a is the type of the data, as seen by the Haskell compiler. If erased, it
will be a Cell type.
-}
data ComputeNode loc ref a =
    ComputeNodeTop !(TopNode loc a)
  | ComputeNodeCol !ColumnData
  deriving (Eq)


{-| A generalization of the column operation.

This structure is useful to performn some extra operations not supported by
the Spark engine:
 - express joins with an observable
 - keep track of DAGs of column operations (not implemented yet)
-}
data GeneralizedColOp =
    GenColExtraction !FieldPath
  | GenColFunction !SqlFunctionName !(Vector GeneralizedColOp)
  | GenColLit !DataType !Cell
    -- This is the extra operation that needs to be flattened with a broadcast.
  | BroadcastColOp !UntypedLocalData
  | GenColStruct !(Vector GeneralizedTransField)
  deriving (Eq)

data GeneralizedTransField = GeneralizedTransField {
  gtfName :: !FieldName,
  gtfValue :: !GeneralizedColOp
} deriving (Eq)

-- (internal) Phantom type tags for the locality
newtype TypedLocality loc = TypedLocality { unTypedLocality :: Locality } deriving (Eq, Show)
data LocLocal
data LocDistributed
data LocUnknown

{-| (developer) The type for which we drop all the information expressed in
types.

This is useful to express parent dependencies (pending a more type-safe
interface)

Note: it is always a top-level node.

-}
type UntypedComputeTopNode = ComputeNode LocUnknown RefSelf Cell

{-| A top-level node, which is either a dataset or an observable.

This type differentiates from the colums, which may be either datasets or
strict subsets of a node.

In this case, the reference is its own type (subject to change).
-}
type TopLevelNode loc a = ComputeNode loc RefSelf a

{-| A typed collection of distributed data.

Most operations on datasets are type-checked by the Haskell
compiler: the type tag associated to this dataset is guaranteed
to be convertible to a proper Haskell type. In particular, building
a Dataset of dynamic cells is guaranteed to never happen.

If you want to do untyped operations and gain
some flexibility, consider using UDataFrames instead.

Computations with Datasets and observables are generally checked for
correctness using the type system of Haskell.
-}
type Dataset a = TopLevelNode LocDistributed a

{-| (internal) A dataset for which we have dropped type information.
Used internally by columns.
-}
type UntypedDataset = ComputeNode LocDistributed RefSelf Cell


{-|
A unit of data that can be accessed by the user.

This is a typed unit of data. The type is guaranteed to be a proper
type accessible by the Haskell compiler (instead of simply a Cell
type, which represents types only accessible at runtime).

TODO(kps) rename to Observable
-}
type LocalData a = TopLevelNode LocLocal a

{-| An observable for which the type is only known dynamically.
-}
type UntypedLocalData = ComputeNode LocLocal RefSelf Cell

{-|
The dataframe type. Any dataset can be converted to a dataframe.

For the Spark users: this is different than the definition of the
dataframe in Spark, which is a dataset of rows. Because the support
for single columns is more akward in the case of rows, it is more
natural to generalize datasets to contain cells.
When communicating with Spark, though, single cells are wrapped
into rows with single field, as Spark does.
-}
type DataFrame = Try UntypedDataset

{-| Observable, whose type can only be infered at runtime and
that can fail to be computed at runtime.

Any observable can be converted to an untyped
observable.

Untyped observables are more flexible and can be combined in
arbitrary manner, but they will fail during the validation of
the Spark computation graph.

TODO(kps) rename to DynObservable
-}
type LocalFrame = Try UntypedLocalData

-- TODO: is it useful?
type UntypedComputeTopNode' = Try UntypedComputeTopNode

{-| A type that indicates if a column is a dataset (a column whose reference
column is itself).
-}
data RefSelf
{-| The reference is unknown.
-}
type RefUnknown = RefSelf

{-| The different paths of edges in the compute DAG of nodes, at the
start of computations.

 - scope edges specify the scope of a node for naming. They are not included in
   the id.

-}
data NodeEdge = ScopeEdge | DataStructureEdge StructureEdge deriving (Show, Eq)

{-| The edges in a compute DAG, after name resolution (which is where most of
the checks and computations are being done)

- parent edges are the direct parents of a node, the only ones required for
  defining computations. They are included in the id.
- logical edges define logical dependencies between nodes to force a specific
  ordering of the nodes. They are included in the id.
-}
data StructureEdge = ParentEdge | LogicalEdge deriving (Show, Eq)


class CheckedLocalityCast loc where
  _validLocalityValues :: [TypedLocality loc]

-- Class to retrieve the locality associated to a type.
-- Is it better to use type classes?
class (CheckedLocalityCast loc) => IsLocality loc where
  _getTypedLocality :: TypedLocality loc

instance CheckedLocalityCast LocLocal where
  _validLocalityValues = [TypedLocality Local]

instance CheckedLocalityCast LocDistributed where
  _validLocalityValues = [TypedLocality Distributed]

-- LocLocal is a locality associated to Local
instance IsLocality LocLocal where
  _getTypedLocality = TypedLocality Local

-- LocDistributed is a locality associated to Distributed
instance IsLocality LocDistributed where
  _getTypedLocality = TypedLocality Distributed

instance CheckedLocalityCast LocUnknown where
  _validLocalityValues = [TypedLocality Distributed, TypedLocality Local]

instance Eq ColumnData where
  (==) = (==) `on` (_cOrigin &&& _cType &&& _cOp &&& _cReferingPath)
