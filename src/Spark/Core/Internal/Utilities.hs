{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE OverloadedStrings #-}


{-| A collection of small utility functions.
-}
module Spark.Core.Internal.Utilities(
  HasCallStack,
  UnknownType,
  myGroupBy,
  myGroupBy',
  missing,
  failure,
  failure',
  forceRight,
  show',
  withContext,
  strictList,
  traceHint,
  SF.sh,
  (<&>),
  (<>)
  ) where

import qualified Data.Text as T
import qualified Formatting.ShortFormatters as SF
import Control.Arrow ((&&&))
import Data.List
import Data.Function
import Data.Text(Text)
import Formatting
import Debug.Trace(trace)
import qualified Data.Map.Strict as M
import Data.Monoid((<>))
import GHC.Stack(HasCallStack)

-- import qualified Spark.Core.Internal.LocatedBase as LB

(<&>) :: Functor f => f a -> (a -> b) -> f b
(<&>) = flip fmap

-- | A type that is is not known and that is not meant to be exposed to the
-- user.
data UnknownType

-- | group by
-- TODO: have a non-empty list instead
myGroupBy' :: (Ord b) => (a -> b) -> [a] -> [(b, [a])]
myGroupBy' f = map (f . head &&& id)
                   . groupBy ((==) `on` f)
                   . sortBy (compare `on` f)

-- | group by
-- TODO: have a non-empty list instead
myGroupBy :: (Ord a) => [(a, b)] -> M.Map a [b]
myGroupBy l = let
  l2 = myGroupBy' fst l in
  M.map (snd <$>) $ M.fromList l2


error' :: (HasCallStack) => Text -> a
error' = error . T.unpack

-- | Missing implementations in the code base.
missing :: (HasCallStack) => Text -> a
missing msg = error' $ T.concat ["MISSING IMPLEMENTATION: ", msg]

{-| The function that is used to trigger exception due to internal programming
errors.

Currently, all programming errors simply trigger an exception. All these
impure functions are tagged with an implicit call stack argument.
-}
failure :: (HasCallStack) => Text -> a
failure msg = error' (T.concat ["FAILURE in Spark. Hint: ", msg])

failure' :: (HasCallStack) => Format Text (a -> Text) -> a -> c
failure' x = failure . sformat x


{-| Given a DataFrame or a LocalFrame, attempts to get the value,
or throws the error.

This function is not total.
-}
forceRight :: (HasCallStack, Show a) => Either a b -> b
forceRight (Right b) = b
forceRight (Left a) = error' $
  sformat ("Failure from either, got instead a left: "%shown) a

-- | Force the complete evaluation of a list to WNF.
strictList :: (Show a) => [a] -> [a]
strictList [] = []
strictList (h : t) = let !t' = strictList t in (h : t')

-- | (internal) prints a hint with a value
traceHint :: (Show a) => Text -> a -> a
traceHint hint x = trace (T.unpack hint ++ show x) x

-- | show with Text
show' :: (Show a) => a -> Text
show' x = T.pack (show x)

withContext :: Text -> Either Text a -> Either Text a
withContext _ (Right x) = Right x
withContext msg (Left other) = Left (msg <> "\n>>" <> other)
