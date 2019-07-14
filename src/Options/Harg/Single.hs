{-# LANGUAGE DerivingStrategies         #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE PolyKinds                  #-}
{-# LANGUAGE StandaloneDeriving         #-}
{-# LANGUAGE UndecidableInstances       #-}
module Options.Harg.Single where

import qualified Data.Functor.Product as P
import           Data.Kind            (Type)
import           GHC.Generics         (Generic)

import qualified Data.Aeson           as JSON

import qualified Data.Barbie          as B


newtype Single (a :: Type) (f :: Type -> Type)
  = Single
      { getSingle :: f a
      }

single :: f a -> Single a f
single = Single

deriving instance (Show a, Show (f a)) => Show (Single a f)
deriving newtype instance Generic (f a) => Generic (Single a f)
deriving newtype instance JSON.FromJSON (f a) => JSON.FromJSON (Single a f)

instance B.FunctorB (Single a) where
  bmap nat (Single p) = Single (nat p)

instance B.TraversableB (Single a) where
  btraverse nat (Single p) = Single <$> nat p

instance B.ProductB (Single a) where
  bprod (Single l) (Single r) = Single (P.Pair l r)
  buniq = Single