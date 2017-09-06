{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE MultiParamTypeClasses #-}

{-| This module takes compute graph and turns them into a string representation
 that is easy to display using TensorBoard. See the python and Haskell
 frontends to see how to do that given the string representations.
-}
module Spark.Core.Internal.Display() where
