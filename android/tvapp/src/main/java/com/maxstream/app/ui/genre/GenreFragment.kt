package com.maxstream.app.ui.genre

import android.content.Intent
import android.os.Bundle
import androidx.leanback.app.BrowseSupportFragment
import androidx.leanback.widget.ArrayObjectAdapter
import androidx.leanback.widget.HeaderItem
import androidx.leanback.widget.ListRow
import androidx.leanback.widget.ListRowPresenter
import androidx.leanback.widget.OnItemViewClickedListener
import androidx.lifecycle.lifecycleScope
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.data.repository.CatalogRepository
import com.maxstream.app.di.Modules
import com.maxstream.app.ui.details.DetailsActivity
import com.maxstream.app.ui.presentation.CardPresenter
import kotlinx.coroutines.launch

class GenreFragment : BrowseSupportFragment() {
    private val repo: CatalogRepository = Modules.catalogRepository
    private lateinit var rowsAdapter: ArrayObjectAdapter
    private var selectedType = "movie"
    private var movieGenres = emptyMap<Int, String>()
    private var tvGenres = emptyMap<Int, String>()
    private var mode = 0
    private var activeGenreId = -1
    private var activeGenreName = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        rowsAdapter = ArrayObjectAdapter(ListRowPresenter())
        adapter = rowsAdapter
        headersState = HEADERS_HIDDEN
        title = "Genres"
    }

    override fun onActivityCreated(savedInstanceState: Bundle?) {
        super.onActivityCreated(savedInstanceState)
        setOnItemViewClickedListener(OnItemViewClickedListener { _, item, _, _ ->
            if (item is MediaItem) onItemClicked(item)
        })
        loadGenres()
        showGenres()
    }

    private fun loadGenres() {
        lifecycleScope.launch {
            runCatching { repo.genres("movie") }.onSuccess { movieGenres = it }
            runCatching { repo.genres("tv") }.onSuccess { tvGenres = it }
            if (mode == 0) showGenres()
        }
    }

    private fun onItemClicked(item: MediaItem) {
        when (item.mediaType) {
            "toggle" -> {
                selectedType = if (selectedType == "movie") "tv" else "movie"
                showGenres()
            }
            "back" -> showGenres()
            "genre" -> {
                activeGenreId = item.id
                activeGenreName = item.title
                mode = 1
                loadGenreContent()
            }
            else -> {
                startActivity(
                    Intent(requireActivity(), DetailsActivity::class.java)
                        .putExtra(DetailsActivity.EXTRA_ITEM, item.toBundle()),
                )
            }
        }
    }

    private fun showGenres() {
        mode = 0
        title = "Genres"
        rowsAdapter.clear()
        val typeCard = MediaItem(
            id = -1, mediaType = "toggle",
            title = if (selectedType == "movie") "Switch to TV Shows ▶" else "Switch to Movies ▶",
            overview = "", posterPath = null, backdropPath = null, releaseDate = "", voteAverage = 0.0,
            genreIds = emptyList(),
        )
        val genreList = (if (selectedType == "movie") movieGenres else tvGenres)
            .map { (id, name) ->
                MediaItem(
                    id = id, mediaType = "genre", title = name, overview = "",
                    posterPath = null, backdropPath = null, releaseDate = "", voteAverage = 0.0,
                    genreIds = emptyList(),
                )
            }
        val row = ArrayObjectAdapter(CardPresenter()).apply {
            add(typeCard)
            addAll(1, genreList)
        }
        rowsAdapter.add(ListRow(HeaderItem("Browse ${if (selectedType == "movie") "Movies" else "TV Shows"}".hashCode().toLong(), "Browse ${if (selectedType == "movie") "Movies" else "TV Shows"}"), row))
    }

    private fun loadGenreContent() {
        lifecycleScope.launch {
            val items = runCatching {
                if (selectedType == "movie") repo.catalogByGenre(activeGenreId, "movie")
                else repo.catalogByGenre(activeGenreId, "tv")
            }.getOrDefault(emptyList())

            rowsAdapter.clear()
            val backCard = MediaItem(
                id = -2, mediaType = "back", title = "← Back to Genres", overview = "",
                posterPath = null, backdropPath = null, releaseDate = "", voteAverage = 0.0,
                genreIds = emptyList(),
            )
            val row = ArrayObjectAdapter(CardPresenter()).apply {
                add(backCard)
                addAll(1, items)
            }
            rowsAdapter.add(ListRow(HeaderItem(activeGenreName.hashCode().toLong(), activeGenreName), row))
        }
    }
}
