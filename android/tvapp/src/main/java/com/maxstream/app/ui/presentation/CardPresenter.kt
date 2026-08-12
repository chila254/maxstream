package com.maxstream.app.ui.presentation

import android.view.ViewGroup
import android.widget.ImageView
import androidx.leanback.widget.ImageCardView
import androidx.leanback.widget.Presenter
import com.bumptech.glide.Glide
import com.bumptech.glide.request.RequestOptions
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.R

/**
 * Renders a [MediaItem] as a Leanback [ImageCardView] (poster + title).
 */
class CardPresenter : Presenter() {
    companion object {
        private const val CARD_WIDTH = 176
        private const val CARD_HEIGHT = 264
    }

    override fun onCreateViewHolder(parent: ViewGroup): ViewHolder {
        val cardView = ImageCardView(parent.context).apply {
            isFocusable = true
            isFocusableInTouchMode = true
            setMainImageDimensions(CARD_WIDTH, CARD_HEIGHT)
        }
        return ViewHolder(cardView)
    }

    override fun onBindViewHolder(viewHolder: ViewHolder, item: Any?) {
        val cardView = viewHolder.view as ImageCardView
        val media = item as? MediaItem ?: return
        cardView.titleText = media.title
        cardView.contentText = media.releaseDate.take(4)
        if (media.posterUrl.isNotBlank()) {
            Glide.with(cardView.context)
                .load(media.posterUrl)
                .apply(RequestOptions().centerCropTransform().error(R.drawable.tv_card_fallback))
                .into(cardView.mainImageView)
        } else {
            cardView.mainImage = cardView.resources.getDrawable(R.drawable.tv_card_fallback, null)
        }
    }

    override fun onUnbindViewHolder(viewHolder: ViewHolder) {
        val cardView = viewHolder.view as ImageCardView
        Glide.with(cardView.context).clear(cardView.mainImageView)
        cardView.mainImage = null
    }

    private val ImageCardView.mainImageView: ImageView
        get() = findViewById(androidx.leanback.R.id.main_image)
}
