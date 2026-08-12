package com.maxstream.app.ui.search

import android.content.Intent
import android.os.Bundle
import androidx.leanback.app.SearchSupportFragment
import androidx.leanback.app.SearchSupportFragment.SearchResultProvider
import androidx.leanback.widget.ArrayObjectAdapter
import androidx.leanback.widget.HeaderItem
import androidx.leanback.widget.ListRow
import androidx.leanback.widget.ListRowPresenter
import androidx.leanback.widget.ObjectAdapter
import androidx.leanback.widget.OnItemViewClickedListener
import androidx.lifecycle.lifecycleScope
import com.maxstream.app.R
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.di.Modules
import com.maxstream.app.ui.details.DetailsActivity
import com.maxstream.app.ui.presentation.CardPresenter
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class SearchFragment : SearchSupportFragment(), SearchResultProvider {
    private val repo = Modules.catalogRepository
    private lateinit var rowsAdapter: ArrayObjectAdapter
    private var query = ""
    private var job: Job? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        rowsAdapter = ArrayObjectAdapter(ListRowPresenter())
        setSearchResultProvider(this)
        setOnItemViewClickedListener(OnItemViewClickedListener { _, item, _, _ ->
            if (item is MediaItem) {
                startActivity(
                    Intent(requireActivity(), DetailsActivity::class.java)
                        .putExtra(DetailsActivity.EXTRA_ITEM, item.toBundle()),
                )
            }
        })
    }

    override fun getResultsAdapter(): ObjectAdapter = rowsAdapter

    override fun onQueryTextChange(newQuery: String): Boolean {
        query = newQuery
        scheduleSearch(newQuery)
        return true
    }

    override fun onQueryTextSubmit(query: String): Boolean {
        this.query = query
        runSearch(query)
        return true
    }

    private fun scheduleSearch(q: String) {
        job?.cancel()
        job = lifecycleScope.launch {
            delay(400)
            runSearch(q)
        }
    }

    private fun runSearch(q: String) {
        val term = q.trim()
        if (term.isEmpty()) {
            rowsAdapter.clear()
            return
        }
        lifecycleScope.launch {
            val results = runCatching { repo.search(term) }.getOrDefault(emptyList())
            rowsAdapter.clear()
            if (results.isNotEmpty()) {
                val row = ArrayObjectAdapter(CardPresenter()).apply { addAll(0, results) }
                rowsAdapter.add(ListRow(HeaderItem("Results".hashCode().toLong(), "Results for \"$term\""), row))
            } else {
                val empty = ArrayObjectAdapter(CardPresenter())
                empty.add(
                    MediaItem(-1, "empty", "No results", "", null, null, "", 0.0, emptyList()),
                )
                rowsAdapter.add(ListRow(HeaderItem("Empty".hashCode().toLong(), "Results"), empty))
            }
        }
    }
}
