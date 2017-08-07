{-# LANGUAGE DeriveGeneric #-}

module Spark.Proto.Graph.All where

import Data.Text
import GHC.Generics (Generic)
import Data.Aeson


data OpExtra = OpExtra {
  content :: !(Maybe Text)
} deriving (Show, Generic)
instance FromJSON OpExtra
instance ToJSON OpExtra
