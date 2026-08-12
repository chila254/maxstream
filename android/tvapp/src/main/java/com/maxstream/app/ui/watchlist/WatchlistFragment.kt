package com.maxstream.app.ui.watchlist

import android.content.Intent
import android.os.Bundle
import androidx.leanback.app.BrowseSupportFragment
import androidx.leanback.widget.ArrayObjectAdapter
import androidx.leanback.widget.HeaderItem
import androidx.leanback.widget.ListRow
import androidx.leanback.widget.ListRowPresenter
import androidx.leanback.widget.OnItemViewClickedListener
import com.maxstream.app.R
import com.maxstream.app.data.local.WatchlistRepository
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.ui.details.DetailsActivity
import com.maxstream.app.ui.presentation.CardPresenter

class WatchlistFragment : BrowseSupportFragment() {
    private lateinit var rowsAdapter: ArrayObjectAdapter
    private var tab = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        rowsAdapter = ArrayObjectAdapter(ListRowPresenter())
        adapter = rowsAdapter
        headersState = HEADERS_HIDDEN
        title = "My Watchlist"
    }

    override fun onActivityCreated(savedInstanceState: Bundle?) {
        super.onActivityCreated(savedInstanceState)
        setOnItemViewClickedListener(OnItemViewClickedListener { _, item, _, _ ->
            if (item is MediaItem) {
                when (item.mediaType) {
                    "watchlist_tab" -> {
                        tab = (item.id + 100).coerceIn(0, 2)
                        rebuild()
                    }
                    "empty" -> { /* no-op */ }
                    else -> startActivity(
                        Intent(requireActivity(), DetailsActivity::class.java)
                            .putExtra(DetailsActivity.EXTRA_ITEM, item.toBundle()),
                    )
                }
            }
        })
        rebuild()
    }

    override fun onResume() {
        super.onResume()
        rebuild()
    }

    private fun allItems(): List<MediaItem> = WatchlistRepository.getAll(requireContext())
    private fun visibleItems(): List<MediaItem> = when (tab) {
        1 -> allItems().filter { it.mediaType == "movie" }
        2 -> allItems().filter { it.mediaType == "tv" }
        else -> allItems()
    }

    private fun rebuild() {
        rowsAdapter.clear()
        val tabs = listOf("All", "Movies", "Series")
        val tabRow = ArrayObjectAdapter(CardPresenter()).apply {
            tabs.forEachIndexed { index, label ->
                add(
                    MediaItem(
                        id = -100 - index, mediaType = "watchlist_tab", title = "$label (${countFor(index)})",
                        overview = "", posterPath = null, backdropPath = null, releaseDate = "",
                        voteAverage = 0.0, genreIds = emptyList(),
                    ),
                )
            }
        }
        rowsAdapter.add(ListRow(HeaderItem("Filter".hashCode().toLong(), "Filter"), tabRow))

        val items = visibleItems()
        if (items.isEmpty()) {
            val empty = ArrayObjectAdapter(CardPresenter())
            empty.add(
                MediaItem(
                    id = -999, mediaType = "empty", title = "Nothing saved here yet",
                    overview = "", posterPath = null, backdropPath = null, releaseDate = "",
                    voteAverage = 0.0, genreIds = emptyList(),
                ),
            )
            rowsAdapter.add(ListRow(HeaderItem("Watchlist".hashCode().toLong(), "Watchlist"), empty))
            return
        }
        val row = ArrayObjectAdapter(CardPresenter()).apply { addAll(0, items) }
        rowsAdapter.add(ListRow(HeaderItem("Saved".hashCode().toLong(), "Saved"), row))
    }

    private fun countFor(index: Int): Int = when (index) {
        1 -> allItems().count { it.mediaType == "movie" }
        2 -> allItems().count { it.mediaType == "tv" }
        else -> allItems().size
    }
}
