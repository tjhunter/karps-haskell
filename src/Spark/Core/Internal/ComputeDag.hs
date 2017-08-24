{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}


{-| A data structure that is more oriented towards expressing graphs of
computations.

The difference with a generic DAG lies in the tables of inputs and outputs
of the graph, which express the idea of inputs and outputs.
-}
module Spark.Core.Internal.ComputeDag(
  ComputeDag(..),
  computeGraphToGraph,
  graphToComputeGraph,
  mapVertices,
  mapVertexData,
  buildCGraph,
  graphDataLexico,
  buildCGraphFromList,
  computeGraphMapVertices
) where

import Data.Foldable(toList)
import qualified Data.Map.Strict as M
import qualified Data.Vector as V
import qualified Data.Text as T
import Data.Vector(Vector)
import Control.Arrow((&&&))
import Control.Monad.Except
import Formatting

import Spark.Core.Internal.DAGStructures
import Spark.Core.Internal.Utilities


import Spark.Core.Internal.DAGFunctions

{-| A DAG of computation nodes.

At a high level, it is a total function with a number of inputs and a number
of outputs.

Note about the edges: the edges flow along the path of dependencies:
the inputs are the start points, and the outputs are the end points of the
graph.

-}
-- TODO: hide the constructor
data ComputeDag v e = ComputeDag {
  -- The edges that make up the DAG
  cdEdges :: !(AdjacencyMap v e),
  -- All the vertices of the graph
  -- Sorted by lexicographic order + node id for uniqueness
  cdVertices :: !(Vector (Vertex v)),
  -- The inputs of the computation graph. These correspond to the
  -- sinks of the dependency graph.
  cdInputs :: !(Vector (Vertex v)),
  -- The outputs of the computation graph. These correspond to the
  -- sources of the dependency graph.
  cdOutputs :: !(Vector (Vertex v))
} deriving (Show)


-- | Conversion
computeGraphToGraph :: ComputeDag v e -> Graph v e
computeGraphToGraph cg =
  Graph (cdEdges cg) (cdVertices cg)

-- | Conversion
graphToComputeGraph :: Graph v e -> ComputeDag v e
graphToComputeGraph g =
  ComputeDag {
    cdEdges = gEdges g,
    cdVertices = gVertices g,
    -- We work on the graph of dependencies (not flows)
    -- The sources correspond to the outputs.
    cdInputs = V.fromList $ graphSinks g,
    cdOutputs = V.fromList $ graphSources g
  }

mapVertices :: (Vertex v -> v') -> ComputeDag v e -> ComputeDag v' e
mapVertices f cd =
  let f' vx = vx { vertexData = f vx }
  in ComputeDag {
      cdEdges = _mapVerticesAdj f (cdEdges cd),
      cdVertices = f' <$> cdVertices cd,
      cdInputs = f' <$> cdInputs cd,
      cdOutputs = f' <$> cdOutputs cd
    }

mapVertexData :: (v -> v') -> ComputeDag v e -> ComputeDag v' e
mapVertexData f = mapVertices (f . vertexData)

buildCGraph :: (GraphOperations v e, Show v) =>
  v -> DagTry (ComputeDag v e)
buildCGraph n = graphToComputeGraph <$> buildGraph n

{-| Builds a compute graph from a list of vertex and edge informations.

If it succeeds, the graph is correct.
-}
buildCGraphFromList :: forall v e. (Show v) =>
  [Vertex v] -> -- The vertices
  [Edge e] -> -- The edges
  [VertexId] -> -- The ids of the inputs
  [VertexId] -> -- The ids of the outputs
  DagTry (ComputeDag v e)
buildCGraphFromList vxs eds inputs outputs = do
  g <- buildGraphFromList vxs eds
  -- Try to tie the inputs and outputs to nodes.
  let vertexById = myGroupBy $ (vertexId &&& id) <$> vxs
  let f :: VertexId -> DagTry (Vertex v)
      f vid = case M.lookup vid vertexById of
        Just [vx] -> pure vx
        _ -> throwError $ sformat ("buildCGraphFromList: a vertex id:"%sh%" is not part of the graph.") vid
  inputs' <- sequence $ f <$> V.fromList inputs
  outputs' <- sequence $ f <$> V.fromList outputs
  return ComputeDag {
      cdEdges = gEdges g,
      cdVertices = gVertices g,
      cdInputs = inputs',
      cdOutputs = outputs'
    }

{-| The content of a compute graph, returned in lexicograph order.
-}
graphDataLexico :: ComputeDag v e -> [v]
graphDataLexico cd = vertexData <$> toList (cdVertices cd)


computeGraphMapVertices :: forall m v e v2. (HasCallStack, Show v2, Monad m) =>
  ComputeDag v e -> -- The start graph
  (v -> [(v2,e)] -> m v2) -> -- The transform
  m (ComputeDag v2 e)
computeGraphMapVertices cd fun = do
  let g = computeGraphToGraph cd
  g' <- graphMapVertices g fun
  let vxs = gVertices g'
  inputs <- _getSubsetVertex vxs (vertexId <$> cdInputs cd)
  outputs <- _getSubsetVertex vxs (vertexId <$> cdOutputs cd)
  return ComputeDag {
    cdEdges = gEdges g',
    cdVertices = gVertices g',
    cdInputs = inputs,
    cdOutputs = outputs
  }

-- Tries to get a subset of the vertices (by vertex id), and fails if
-- one is missing.
_getSubsetVertex :: forall v m. (Monad m) => Vector (Vertex v) -> Vector VertexId -> m (Vector (Vertex v))
_getSubsetVertex vxs vids =
  let vertexById = myGroupBy $ (vertexId &&& id) <$> V.toList vxs
      f :: VertexId -> m (Vertex v)
      f vid = case M.lookup vid vertexById of
        Just [vx] -> pure vx
        -- A failure here is a construction error of the graph.
        _ -> fail . T.unpack $ sformat ("buildCGraphFromList: a vertex id:"%sh%" is not part of the graph.") vid
  in sequence $ f <$> vids

_mapVerticesAdj :: (Vertex v -> v') -> AdjacencyMap v e -> AdjacencyMap v' e
_mapVerticesAdj f m =
  let f1 ve =
        let vx = veEndVertex ve
            d' = f vx in
          ve { veEndVertex = vx { vertexData = d' } }
      f' v = f1 <$> v
  in M.map f' m
