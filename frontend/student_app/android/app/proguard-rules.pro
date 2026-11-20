# Razorpay Checkout (razorpay_flutter). From Razorpay's Android integration guide: keep the SDK and the
# onPayment* callbacks it calls by reflection, or release (R8-shrunk) builds crash when checkout opens.
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** {*;}
-optimizations !method/inlining/
-keepclasseswithmembers class * {
  public void onPayment*(...);
}
