package com.maxstream.app.ui.home

import android.content.Intent
import android.os.Bundle
import androidx.leanback.app.BrowseSupportFragment
import androidx.leanback.widget.ArrayObjectAdapter
import androidx.leanback.widget.HeaderItem
import androidx.leanback.widget.ListRow
import androidx.leanback.widget.ListRowPresenter
import androidx.leanback.widget.OnItemViewClickedListener
import androidx.lifecycle.ViewModelProvider
import com.maxstream.app.R
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.ui.details.DetailsActivity
import com.maxstream.app.ui.presentation.CardPresenter
import com.maxstream.app.ui.viewmodel.HomeViewModel

class HomeFragment : BrowseSupportFragment() {
    private lateinit var viewModel: HomeViewModel
    private lateinit var rowsAdapter: ArrayObjectAdapter

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        viewModel = ViewModelProvider(this)[HomeViewModel::class.java]
    }

    override fun onActivityCreated(savedInstanceState: Bundle?) {
        super.onActivityCreated(savedInstanceState)
        headersState = HEADERS_HIDDEN
        title = "MaxStream"
        rowsAdapter = ArrayObjectAdapter(ListRowPresenter())
        adapter = rowsAdapter
        observeData()
        setOnItemViewClickedListener(OnItemViewClickedListener { _, item, _, _ ->
            if (item is MediaItem) {
                startActivity(
                    Intent(requireActivity(), DetailsActivity::class.java)
                        .putExtra(DetailsActivity.EXTRA_ITEM, item.toBundle()),
                )
            }
        })
    }

    private fun observeData() {
        viewModel.trendingMovies.observe(viewLifecycleOwner) { addRow("Trending Movies", it) }
        viewModel.trendingSeries.observe(viewLifecycleOwner) { addRow("Trending Series", it) }
        viewModel.popularMovies.observe(viewLifecycleOwner) { addRow("Popular Movies", it) }
        viewModel.popularSeries.observe(viewLifecycleOwner) { addRow("Popular Series", it) }
        viewModel.topRatedMovies.observe(viewLifecycleOwner) { addRow("Top Rated Movies", it) }
        viewModel.topRatedSeries.observe(viewLifecycleOwner) { addRow("Top Rated Series", it) }
    }

    private fun addRow(title: String, items: List<MediaItem>) {
        if (items.isEmpty()) return
        val existing = (0 until rowsAdapter.size()).firstOrNull { index ->
            (rowsAdapter[index] as? ListRow)?.headerItem?.name == title
        }
        if (existing != null) {
            val row = rowsAdapter[existing] as ListRow
            val adapter = row.adapter as ArrayObjectAdapter
            adapter.clear()
            adapter.addAll(0, items)
        } else {
            val listRowAdapter = ArrayObjectAdapter(CardPresenter()).apply { addAll(0, items) }
            rowsAdapter.add(ListRow(HeaderItem(title.hashCode().toLong(), title), listRowAdapter))
        }
    }
}
