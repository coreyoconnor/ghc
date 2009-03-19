{-# OPTIONS -fglasgow-exts #-}
module TH_tf1 where

$( [d| data family T a |] )
$( [d| data instance T Int = TInt Bool |] )

foo :: Bool -> T Int
foo b = TInt (b && b)

$( [d| type family S a |] )
$( [d| type instance S Int = Bool |] )

bar :: S Int -> Int
bar c = if c then 1 else 2
