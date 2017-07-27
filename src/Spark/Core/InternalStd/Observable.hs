
module Spark.Core.InternalStd.Observable(
  asDouble) where

import qualified Spark.Core.InternalStd.Column as C
import Spark.Core.Internal.DatasetStructures
import Spark.Core.Internal.FunctionsInternals
import Spark.Core.Internal.TypesGenerics(SQLTypeable)

{-| Casts a local data as a double.
-}
asDouble :: (Num a, SQLTypeable a) => LocalData a -> LocalData Double
asDouble = projectColFunction C.asDouble
