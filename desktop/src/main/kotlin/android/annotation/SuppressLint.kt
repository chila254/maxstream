package android.annotation

/** Desktop stand-in for @SuppressLint — no-op marker so TV code compiles as-is. */
@Target(
    AnnotationTarget.FUNCTION,
    AnnotationTarget.PROPERTY,
    AnnotationTarget.PROPERTY_GETTER,
    AnnotationTarget.PROPERTY_SETTER,
    AnnotationTarget.CLASS,
    AnnotationTarget.FILE,
    AnnotationTarget.CONSTRUCTOR,
)
@Retention(AnnotationRetention.SOURCE)
annotation class SuppressLint(vararg val value: String = [])