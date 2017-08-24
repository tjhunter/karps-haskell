{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE DeriveAnyClass#-}

module Spark.Proto.Graph.All where

import Data.Text
import GHC.Generics (Generic)
import Data.Aeson

data OpExtra = OpExtra {
  content :: !(Maybe Text)
} deriving (Show, Generic, Eq, FromJSON, ToJSON)
