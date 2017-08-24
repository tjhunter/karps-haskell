{-# LANGUAGE OverloadedStrings #-}

{-| The data structures for the server part -}
module Spark.Server.Transform where


import Data.HashMap.Strict as HM
import qualified Data.Map.Strict as M
import qualified Data.Vector as V
import Debug.Trace

import Spark.Core.Internal.TypesFunctions()
import Spark.Core.Try
import Spark.Server.Structures
import Spark.Core.Internal.ContextInternal
import Spark.Core.Context(defaultConf)
import Spark.Core.Internal.ContextStructures
import Spark.Core.Internal.Utilities(show')
import Spark.Core.Internal.DAGStructures
-- Required to import the instances.
import Spark.Core.Internal.Paths()


{-| The main compiler function.

TODO: add the Spark options
-}
transform :: GraphTransform -> GraphTransformResult
transform gt = trace ("transform: gt=" ++ show gt) $
  case _transform gt of
    Right cg -> GTRSuccess GraphTransformSuccess {
        gtsNodes = V.toList (vertexData <$> gVertices tied),
        -- gtsTerminalNodes = V.toList (vertexData <$> cdOutputs cg'),
        gtsNodeMapUpdate = M.empty
      } where tied = convertToTiedGraph cg
    Left err -> GTRFailure $ GraphTransformFailure (show' err)

_transform :: GraphTransform -> Try ComputeGraph
_transform gt = do
  let g = gtGraph gt
  let c = defaultConf
  let session = SparkSession {
          ssConf = c,
          ssId = gtSessionId gt,
          ssCommandCounter = 0,
          ssNodeCache = HM.empty
        }
  cg2' <- performGraphTransforms session g
  let cg2 = trace ("_transform: cg2'="++show cg2') cg2'
  return cg2
