package com.whowouldin.whowouldwin.ui.screens.share

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.core.content.FileProvider
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.delay
import java.io.File
import java.io.FileOutputStream

/**
 * Renders a Composable off-screen into a Bitmap.
 *
 * Implementation: builds a headless ComposeView with its own LifecycleOwner,
 * measures/lays it out at a fixed size, then uses the Compose 1.7 GraphicsLayer
 * capture pattern (layer.record { drawContent() } + layer.toImageBitmap()) to
 * snapshot the drawing into an ImageBitmap which we convert to android.graphics.Bitmap.
 */
suspend fun renderComposableToBitmap(
    context: Context,
    widthDp: Int,
    heightDp: Int,
    content: @Composable () -> Unit,
): Bitmap {
    val density = context.resources.displayMetrics.density
    val widthPx = (widthDp * density).toInt()
    val heightPx = (heightDp * density).toInt()

    val deferred = CompletableDeferred<Bitmap>()

    val owner = HeadlessLifecycleOwner().also { it.start() }

    val composeView = ComposeView(context).apply {
        setViewTreeLifecycleOwner(owner)
        setViewTreeSavedStateRegistryOwner(owner)
        setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnDetachedFromWindow)
    }

    composeView.setContent {
        val layer = rememberGraphicsLayer()
        Box(
            modifier = Modifier.drawWithContent {
                layer.record { this@drawWithContent.drawContent() }
                drawLayer(layer)
            }
        ) {
            content()
        }
        LaunchedEffect(Unit) {
            // Wait a frame or two so measurement + draw have run.
            delay(64)
            try {
                val image = layer.toImageBitmap()
                deferred.complete(image.asAndroidBitmap())
            } catch (t: Throwable) {
                deferred.completeExceptionally(t)
            }
        }
    }

    composeView.measure(
        android.view.View.MeasureSpec.makeMeasureSpec(widthPx, android.view.View.MeasureSpec.EXACTLY),
        android.view.View.MeasureSpec.makeMeasureSpec(heightPx, android.view.View.MeasureSpec.EXACTLY),
    )
    composeView.layout(0, 0, widthPx, heightPx)

    return try {
        deferred.await()
    } finally {
        owner.destroy()
    }
}

/** Saves [bitmap] into app-external-files/share_cards/ and returns a shareable content:// uri. */
fun saveBitmapForSharing(context: Context, bitmap: Bitmap, fileName: String): Uri {
    val dir = File(context.getExternalFilesDir(null), "share_cards").apply { mkdirs() }
    val file = File(dir, fileName)
    FileOutputStream(file).use { out ->
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
    }
    return FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
}

/** Launches the system share sheet with the supplied PNG uri + optional caption. */
fun launchShareIntent(context: Context, imageUri: Uri, caption: String) {
    val send = Intent(Intent.ACTION_SEND).apply {
        type = "image/png"
        putExtra(Intent.EXTRA_STREAM, imageUri)
        putExtra(Intent.EXTRA_TEXT, caption)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    context.startActivity(
        Intent.createChooser(send, null).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    )
}

/** Minimal LifecycleOwner + SavedStateRegistryOwner for headless ComposeView hosting. */
private class HeadlessLifecycleOwner : LifecycleOwner, SavedStateRegistryOwner {
    private val registry = LifecycleRegistry(this)
    private val savedStateController = SavedStateRegistryController.create(this).also {
        it.performRestore(null)
    }
    override val lifecycle: Lifecycle get() = registry
    override val savedStateRegistry get() = savedStateController.savedStateRegistry
    fun start() { registry.currentState = Lifecycle.State.RESUMED }
    fun destroy() { registry.currentState = Lifecycle.State.DESTROYED }
}
