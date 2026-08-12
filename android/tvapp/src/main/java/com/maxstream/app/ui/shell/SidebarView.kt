package com.maxstream.app.ui.shell

import android.content.Context
import android.graphics.drawable.GradientDrawable
import android.util.AttributeSet
import android.view.Gravity
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.maxstream.app.R

class SidebarView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : LinearLayout(context, attrs) {

    var onItemSelected: ((index: Int) -> Unit)? = null

    private val itemViews = mutableListOf<TextView>()
    private var selectedIndex = 0
    private val titles = listOf("Home", "Search", "Genre", "Series", "Watchlist", "More")

    init {
        orientation = VERTICAL
        setPadding(0, 28, 0, 28)
        background = GradientDrawable(
            GradientDrawable.Orientation.TOP_BOTTOM,
            intArrayOf(0xFF1A1A1A.toInt(), 0xFF111111.toInt()),
        )
        buildLogo()
        titles.forEachIndexed { index, title -> addItem(index, title) }
    }

    private fun buildLogo() {
        val logo = ImageView(context).apply {
            val size = (40 * resources.displayMetrics.density).toInt()
            layoutParams = LayoutParams(size, size).apply { setMargins(0, 0, 0, 28) }
            scaleType = ImageView.ScaleType.CENTER_CROP
            setImageResource(R.mipmap.ic_launcher)
            val pad = (18 * resources.displayMetrics.density).toInt()
            setPadding(pad, 0, pad, 0)
        }
        addView(logo)
    }

    private fun addItem(index: Int, title: String) {
        val item = TextView(context).apply {
            text = title
            textSize = 16f
            setTextColor(0xFFFFFFFF.toInt())
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LayoutParams(
                LayoutParams.MATCH_PARENT,
                (52 * resources.displayMetrics.density).toInt(),
            ).apply { setMargins(12, 4, 12, 4) }
            val pad = (16 * resources.displayMetrics.density).toInt()
            setPadding(pad, 0, pad, 0)
            isFocusable = true
            isFocusableInTouchMode = true
            setOnClickListener { select(index) }
            setOnFocusChangeListener { _, hasFocus -> applyStyle(index, hasFocus) }
        }
        itemViews.add(item)
        addView(item)
        applyStyle(index, false)
    }

    private fun applyStyle(index: Int, focused: Boolean) {
        val item = itemViews[index]
        val bg = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = (28 * resources.displayMetrics.density)
            setColor(
                when {
                    index == selectedIndex -> 0x38FFFFFF
                    focused -> 0x14FFFFFF
                    else -> android.graphics.Color.TRANSPARENT
                }.toInt(),
            )
            if (focused) {
                setStroke(
                    (1.5 * resources.displayMetrics.density).toInt(),
                    0x30FFFFFF,
                )
            }
        }
        item.background = bg
    }

    fun select(index: Int) {
        if (index == selectedIndex) {
            onItemSelected?.invoke(index)
            return
        }
        val previous = selectedIndex
        selectedIndex = index
        applyStyle(previous, itemViews[previous].isFocused)
        applyStyle(index, itemViews[index].isFocused)
        onItemSelected?.invoke(index)
    }

    fun setActive(index: Int) {
        selectedIndex = index
        itemViews.forEachIndexed { i, v -> applyStyle(i, v.isFocused) }
    }

    fun focusItem(index: Int) {
        itemViews.getOrNull(index)?.requestFocus()
    }

    override fun generateDefaultLayoutParams(): ViewGroup.LayoutParams =
        LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
}
