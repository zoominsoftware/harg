{-# LANGUAGE AllowAmbiguousTypes        #-}
{-# LANGUAGE DerivingStrategies         #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE PolyKinds                  #-}
{-# LANGUAGE StandaloneDeriving         #-}
{-# LANGUAGE TypeFamilyDependencies     #-}
{-# LANGUAGE UndecidableInstances       #-}

{-# OPTIONS_GHC -fno-warn-orphans #-}
module Options.Harg.Nested where

import           Data.Coerce      (Coercible, coerce)
import           Data.Kind        (Type)
import           GHC.Generics     (Generic)

import qualified Data.Aeson       as JSON
import qualified Data.Barbie      as B
import qualified Data.Generic.HKD as HKD

-- Orphan HKD FromJSON instance
instance JSON.GFromJSON JSON.Zero (HKD.HKD_ f structure)
    => JSON.FromJSON (Nested structure f) where
  parseJSON
    = fmap (Nested . HKD.HKD)
    . JSON.gParseJSON JSON.defaultOptions JSON.NoFromArgs

newtype Nested (b :: Type) (f :: Type -> Type)
  = Nested (HKD.HKD b f)

type family Nest
    (a :: Type)
    (f :: Type -> Type)
    = (res :: Type) | res -> a where
  Nest (a -> b)      f = a -> Nest b f
  Nest (HKD.HKD a f) f = Nested a f

nested
  :: forall b f k.
     ( HKD.Build b f k
     , Coercible (HKD.HKD b f) (Nested b f)
     , Coercible k (Nest k f)
     )
  => Nest k f
nested = coerce @k @(Nest k f) hkd
  where hkd = HKD.build @b @f @k

getNested
  :: HKD.Construct f b
  => Nested b f
  -> f b
getNested (Nested hkd) = HKD.construct hkd

deriving newtype instance Generic (HKD.HKD b f) => Generic (Nested b f)
-- deriving newtype instance JSON.FromJSON (HKD.HKD b f) => JSON.FromJSON (Nested b f)

deriving newtype instance B.FunctorB (HKD.HKD b) => B.FunctorB (Nested b)
deriving newtype instance B.ProductB (HKD.HKD b) => B.ProductB (Nested b)

instance (B.TraversableB (HKD.HKD b)) => B.TraversableB (Nested b) where
  btraverse nat (Nested hkd) = Nested <$> B.btraverse nat hkd
