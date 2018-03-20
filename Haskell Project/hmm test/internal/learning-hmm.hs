{-# LANGUAGE RecordWildCards #-}

module Learning.HMM.Internal
  ( HMM (..)
  , LogLikelihood
  , init
  , withEmission
  , euclideanDistance
  , viterbi
  , baumWelch
  , baumWelch'
  -- , baumWelch1
  -- , forward
  -- , backward
  -- , posterior
  ) where

import           Control.Applicative                     ( (<$>) )
import           Control.DeepSeq                         ( NFData, force, rnf )
import           Control.Monad                           ( forM_, replicateM )
import           Control.Monad.ST                        ( runST )
import qualified Data.Map.Strict                  as M   ( findWithDefault )
import           Data.Random.Distribution.Simplex        ( stdSimplex )
import           Data.Random.RVar                        ( RVar )
import qualified Data.Vector                      as V   ( Vector, filter, foldl', foldl1', map, unsafeFreeze, unsafeIndex, unsafeTail, zip, zipWith3 )
import qualified Data.Vector.Generic              as G   ( convert )
import qualified Data.Vector.Generic.Extra        as G   ( frequencies )
import qualified Data.Vector.Mutable              as MV  ( unsafeNew, unsafeRead, unsafeWrite )
import qualified Data.Vector.Unboxed              as U   ( Vector, fromList, length, map, sum, unsafeFreeze, unsafeIndex, unsafeTail, zip )
import qualified Data.Vector.Unboxed.Mutable      as MU  ( unsafeNew, unsafeRead, unsafeWrite )
import qualified Numeric.LinearAlgebra.Data       as H   ( (!), Matrix, Vector, diag, fromColumns, fromList, fromLists, fromRows, ident, konst, maxElement, maxIndex, toColumns, tr )
import qualified Numeric.LinearAlgebra.HMatrix    as H   ( (<>), (#>), sumElements )
import           Prelude                          hiding ( init )

type LogLikelihood = Double

-- | More efficient data structure of the 'HMM' model. The 'states' and
--   'outputs' in 'HMM' are represented by their indices. The
--   'initialStateDist', 'transitionDist', and 'emissionDist' are
--   represented by matrices. The 'emissionDistT' is a transposed matrix
--   in order to simplify the calculation.
data HMM = HMM { nStates          :: Int -- ^ Number of states
               , nOutputs         :: Int -- ^ Number of outputs
               , initialStateDist :: H.Vector Double
               , transitionDist   :: H.Matrix Double
               , emissionDistT    :: H.Matrix Double
               }

instance NFData HMM where
    rnf HMM {..} = rnf nStates `seq`
                   rnf nOutputs `seq`
                   rnf initialStateDist `seq`
                   rnf transitionDist `seq`
                   rnf emissionDistT

init :: Int -> Int -> RVar HMM
init k l = do
  pi0 <- H.fromList <$> stdSimplex (k-1)
  w   <- H.fromLists <$> replicateM k (stdSimplex (k-1))
  phi <- H.fromLists <$> replicateM k (stdSimplex (l-1))
  return HMM { nStates          = k
             , nOutputs         = l
             , initialStateDist = q_ H.#> pi0
             , transitionDist   = w H.<> q_
             , emissionDistT    = q_ H.<> H.tr phi
             }
  where
    q_ = q k -- Error matrix

withEmission :: HMM -> U.Vector Int -> HMM
withEmission (model @ HMM {..}) xs = model'
  where
    n  = U.length xs
    ss = [0..(nStates - 1)]
    os = [0..(nOutputs - 1)]

    step m = fst $ baumWelch1 (m { emissionDistT = H.tr phi }) n xs
      where
        phi :: H.Matrix Double
        phi = let zs  = fst $ viterbi m xs
                  fs  = G.frequencies $ U.zip zs xs
                  hs  = H.fromLists $ map (\s -> map (\o ->
                          M.findWithDefault 0 (s, o) fs) os) ss
                  -- hs' is needed to not yield NaN vectors
                  hs' = hs + H.konst 1e-9 (nStates, nOutputs)
                  ns  = hs' H.#> H.konst 1 nStates
              in hs' / H.fromColumns (replicate nOutputs ns)

    ms  = iterate step model
    ms' = tail ms
    ds  = zipWith euclideanDistance ms ms'

    model' = fst $ head $ dropWhile ((> 1e-9) . snd) $ zip ms' ds

euclideanDistance :: HMM -> HMM -> Double
euclideanDistance model model' =
  sqrt $ H.sumElements ((w - w') ** 2) + H.sumElements ((phi - phi') ** 2)
  where
    w    = transitionDist model
    w'   = transitionDist model'
    phi  = emissionDistT model
    phi' = emissionDistT model'

viterbi :: HMM -> U.Vector Int -> (U.Vector Int, LogLikelihood)
viterbi HMM {..} xs = (path, logL)
  where
    n = U.length xs

    -- First, we calculate the value function and the state maximizing it
    -- for each time.
    deltas :: V.Vector (H.Vector Double)
    psis   :: V.Vector (U.Vector Int)
    (deltas, psis) = runST $ do
      ds <- MV.unsafeNew n
      ps <- MV.unsafeNew n
      let x0 = U.unsafeIndex xs 0
      MV.unsafeWrite ds 0 $ log (emissionDistT H.! x0) + log initialStateDist
      forM_ [1..(n-1)] $ \t -> do
        d <- MV.unsafeRead ds (t-1)
        let x   = U.unsafeIndex xs t
            dws = map (\wj -> d + log wj) w'
        MV.unsafeWrite ds t $ log (emissionDistT H.! x) + H.fromList (map H.maxElement dws)
        MV.unsafeWrite ps t $ U.fromList (map H.maxIndex dws)
      ds' <- V.unsafeFreeze ds
      ps' <- V.unsafeFreeze ps
      return (ds', ps')
      where
        w' = H.toColumns transitionDist

    deltaE = V.unsafeIndex deltas (n-1)

    -- The most likely path and corresponding log likelihood are as follows.
    path = runST $ do
      ix <- MU.unsafeNew n
      MU.unsafeWrite ix (n-1) $ H.maxIndex deltaE
      forM_ [n-l | l <- [1..(n-1)]] $ \t -> do
        i <- MU.unsafeRead ix t
        let psi = V.unsafeIndex psis t
        MU.unsafeWrite ix (t-1) $ U.unsafeIndex psi i
      U.unsafeFreeze ix
    logL = H.maxElement deltaE

baumWelch :: HMM -> U.Vector Int -> [(HMM, LogLikelihood)]
baumWelch model xs = zip models (tail logLs)
  where
    n = U.length xs
    step (m, _)     = baumWelch1 m n xs
    (models, logLs) = unzip $ iterate step (model, undefined)

baumWelch' :: HMM -> U.Vector Int -> (HMM, LogLikelihood)
baumWelch' model xs = go (10000 :: Int) (undefined, -1/0) (baumWelch1 model n xs)
  where
    n = U.length xs
    go k (m, l) (m', l')
      | k > 0 && l' - l > 1.0e-9 = go (k - 1) (m', l') (baumWelch1 m' n xs)
      | otherwise                = (m, l')

-- | Perform one step of the Baum-Welch algorithm and return the updated
--   model and the likelihood of the old model.
baumWelch1 :: HMM -> Int -> U.Vector Int -> (HMM, LogLikelihood)
baumWelch1 (model @ HMM {..}) n xs = force (model', logL)
  where
    -- First, we calculate the alpha, beta, and scaling values using the
    -- forward-backward algorithm.
    (alphas, cs) = forward model n xs
    betas        = backward model n xs cs

    -- Based on the alpha, beta, and scaling values, we calculate the
    -- posterior distribution, i.e., gamma and xi values.
    (gammas, xis) = posterior model n xs alphas betas cs

    -- Error matrix
    q_ = q nStates

    -- Using the gamma and xi values, we obtain the optimal initial state
    -- probability vector, transition probability matrix, and emission
    -- probability matrix.
    pi0  = let g0  = V.unsafeIndex gammas 0
               g0_ = g0 / H.konst (H.sumElements g0) nStates
           in q_ H.#> g0_
    w    = let ds = V.foldl1' (+) xis         -- denominators
               ns = ds H.#> H.konst 1 nStates -- numerators
               w_ = H.diag (H.konst 1 nStates / ns) H.<> ds
           in w_ H.<> q_
           {- in H.fromRows $ zipWith3 (\n_ t t0 -> if n_ > eps then t else t0)
            -                          (H.toList ns)
            -                          (H.toRows $ w_ H.<> q_)
            -                          (H.toRows transitionDist)
            -}
    phi' = let gs' o = V.map snd $ V.filter ((== o) . fst) $ V.zip (G.convert xs) gammas
               ds    = V.foldl' (+) (H.konst 0 nStates) . gs'  -- denominators
               ns    = V.foldl1' (+) gammas -- numerators
               phi_  = H.fromRows $ map (\o -> ds o / ns) [0..(nOutputs - 1)]
           in q_ H.<> phi_
           {- in H.fromColumns $ zipWith3 (\n_ e e0 -> if n_ > eps then e else e0)
            -                             (H.toList ns)
            -                             (H.toColumns $ q_ H.<> phi_)
            -                             (H.toColumns emissionDistT)
            -}

    -- We finally obtain the new model and the likelihood for the old model.
    model' = model { initialStateDist = pi0
                   , transitionDist   = w
                   , emissionDistT    = phi'
                   }
    logL = - (U.sum $ U.map log cs)

-- | Return alphas and scaling variables.
forward :: HMM -> Int -> U.Vector Int -> (V.Vector (H.Vector Double), U.Vector Double)
{-# INLINE forward #-}
forward HMM {..} n xs = runST $ do
  as <- MV.unsafeNew n
  cs <- MU.unsafeNew n
  let x0 = U.unsafeIndex xs 0
      a0 = (emissionDistT H.! x0) * initialStateDist
      c0 = 1 / H.sumElements a0
  MV.unsafeWrite as 0 (H.konst c0 nStates * a0)
  MU.unsafeWrite cs 0 c0
  forM_ [1..(n-1)] $ \t -> do
    a <- MV.unsafeRead as (t-1)
    let x  = U.unsafeIndex xs t
        a' = (emissionDistT H.! x) * (w' H.#> a)
        c' = 1 / H.sumElements a'
    MV.unsafeWrite as t (H.konst c' nStates * a')
    MU.unsafeWrite cs t c'
  as' <- V.unsafeFreeze as
  cs' <- U.unsafeFreeze cs
  return (as', cs')
  where
    w' = H.tr transitionDist

-- | Return betas using scaling variables.
backward :: HMM -> Int -> U.Vector Int -> U.Vector Double -> V.Vector (H.Vector Double)
{-# INLINE backward #-}
backward HMM {..} n xs cs = runST $ do
  bs <- MV.unsafeNew n
  let bE = H.konst 1 nStates
      cE = U.unsafeIndex cs (n-1)
  MV.unsafeWrite bs (n-1) (H.konst cE nStates * bE)
  forM_ [n-l | l <- [1..(n-1)]] $ \t -> do
    b <- MV.unsafeRead bs t
    let x  = U.unsafeIndex xs t
        b' = transitionDist H.#> ((emissionDistT H.! x) * b)
        c' = U.unsafeIndex cs (t-1)
    MV.unsafeWrite bs (t-1) (H.konst c' nStates * b')
  V.unsafeFreeze bs

-- | Return the posterior distribution.
posterior :: HMM -> Int -> U.Vector Int -> V.Vector (H.Vector Double) -> V.Vector (H.Vector Double) -> U.Vector Double -> (V.Vector (H.Vector Double), V.Vector (H.Matrix Double))
{-# INLINE posterior #-}
posterior HMM {..} _ xs alphas betas cs = (gammas, xis)
  where
    gammas = V.zipWith3 (\a b c -> a * b / H.konst c nStates)
               alphas betas (G.convert cs)
    xis    = V.zipWith3 (\a b x -> H.diag a H.<> transitionDist H.<> H.diag (b * (emissionDistT H.! x)))
               alphas (V.unsafeTail betas) (G.convert $ U.unsafeTail xs)

-- | Global error threshold.
{-# INLINE eps #-}
eps :: Double
eps = 1e-4

-- | Error matrix @q k@ is required to guarantee that the elements of initial
--   states vector and emission/transition matrix are all larger than zero.
--   @k@ is assumed to be the number of states. @q k@ is given by
--       [    1 - eps, (1/k') eps,        ..., (1/k') eps ]
--       [ (1/k') eps,    1 - eps,        ..., (1/k') eps ]
--       [                    ...                         ]
--       [ (1/k') eps,        ..., (1/k') eps,    1 - eps ],
--   where the diagonal elements are @1 - eps@ and the remains are @(1/k')
--   eps@. Here @eps@ is a small error value (given by @1e-4@) and
--   @k' = k - 1@.
q :: Int -> H.Matrix Double
{-# INLINE q #-}
q k = H.konst (1 - eps) (k, k) * e + H.konst (eps / k') (k, k) * (one - e)
  where
    e   = H.ident k
    one = H.konst 1 (k, k)
    k'  = fromIntegral (k - 1)